import { BadRequestException, ConflictException, ForbiddenException, Inject, Injectable, NotFoundException } from '@nestjs/common';
import bcrypt from 'bcryptjs';
import { EMPLOYEE_STORE, type EmployeeStore } from '../employees/employee.store.js';
import { EMBEDDING_DIM, encryptEmbedding, faceKey, normalize } from './face.crypto.js';
import { FACE_STORE, type FaceStore } from './face.store.js';

/** Versión del texto de consentimiento que muestra la app. Si cambia, hay que volver a aceptar. */
export const FACE_CONSENT_VERSION = '2026-11-v1';
const MIN_CAPTURES = 3;
const MAX_CAPTURES = 5;

export interface FaceStatus {
  currentConsentVersion: string;
  /** Hay consentimiento vigente y es de la versión actual. */
  consented: boolean;
  consentVersion: string | null;
  templates: number;
  pinSet: boolean;
}

function validateEmbedding(v: number[]) {
  if (!Array.isArray(v) || v.length !== EMBEDDING_DIM || v.some((x) => typeof x !== 'number' || !Number.isFinite(x))) {
    throw new BadRequestException(`Cada embedding debe tener ${EMBEDDING_DIM} números finitos`);
  }
  if (v.every((x) => x === 0)) throw new BadRequestException('Embedding vacío');
}

/**
 * Reconocimiento facial: consentimiento, plantillas (solo embeddings cifrados) y PIN de respaldo.
 * La comparación facial no está aquí todavía; será la fase 2.
 */
@Injectable()
export class FaceService {
  constructor(
    @Inject(FACE_STORE) private readonly faces: FaceStore,
    @Inject(EMPLOYEE_STORE) private readonly employees: EmployeeStore,
  ) {}

  async status(employeeId: string): Promise<FaceStatus> {
    const consent = await this.faces.latestConsent(employeeId);
    const active = consent && !consent.revokedAt ? consent : null;
    const employee = await this.employees.findById(employeeId);
    return {
      currentConsentVersion: FACE_CONSENT_VERSION,
      consented: active?.version === FACE_CONSENT_VERSION,
      consentVersion: active?.version ?? null,
      templates: await this.faces.templateCount(employeeId),
      pinSet: Boolean(employee?.pinHash),
    };
  }

  /** El empleado acepta el texto vigente. Aceptar de nuevo mientras está vigente no duplica el registro. */
  async giveConsent(employeeId: string, version: string): Promise<FaceStatus> {
    if (version !== FACE_CONSENT_VERSION) {
      throw new ConflictException(`Acepta la versión vigente del consentimiento (${FACE_CONSENT_VERSION})`);
    }
    const latest = await this.faces.latestConsent(employeeId);
    if (!latest || latest.revokedAt || latest.version !== version) {
      await this.faces.addConsent(employeeId, version);
    }
    return this.status(employeeId);
  }

  /**
   * Guarda 3–5 embeddings cifrados (reemplaza los anteriores) y define el PIN de respaldo.
   * Solo se acepta con consentimiento vigente. Nunca recibe ni guarda imágenes.
   */
  async enroll(employeeId: string, embeddings: number[][], pin: string): Promise<FaceStatus> {
    const current = await this.status(employeeId);
    if (!current.consented) throw new ForbiddenException('Primero acepta el consentimiento de reconocimiento facial');
    if (embeddings.length < MIN_CAPTURES || embeddings.length > MAX_CAPTURES) {
      throw new BadRequestException(`Envía entre ${MIN_CAPTURES} y ${MAX_CAPTURES} capturas`);
    }
    embeddings.forEach(validateEmbedding);

    // Si falta la clave de cifrado, falla antes de guardar nada.
    const key = faceKey();
    const encrypted = embeddings.map((v) => encryptEmbedding(normalize(v), key));

    const employee = await this.employees.findById(employeeId);
    if (!employee) throw new NotFoundException('Empleado no encontrado');
    await this.faces.replaceTemplates(employeeId, encrypted);
    employee.pinHash = await bcrypt.hash(pin, 10);
    await this.employees.save(employee);
    return this.status(employeeId);
  }

  /** Derecho de cancelación: revoca el consentimiento y borra las plantillas. El PIN se conserva. */
  async revoke(employeeId: string): Promise<FaceStatus> {
    await this.faces.revokeConsent(employeeId);
    await this.faces.deleteTemplates(employeeId);
    return this.status(employeeId);
  }
}
