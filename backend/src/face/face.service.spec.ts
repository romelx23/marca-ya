import { randomBytes } from 'node:crypto';
import { BadRequestException, ConflictException, ForbiddenException, ServiceUnavailableException } from '@nestjs/common';
import { describe, expect, it } from 'vitest';
import type { EmployeeRecord, EmployeeStore } from '../employees/employee.store.js';
import { EMBEDDING_DIM, decryptEmbedding, encryptEmbedding, faceKey, normalize } from './face.crypto.js';
import { FACE_CONSENT_VERSION, FaceService } from './face.service.js';
import type { FaceConsentRecord, FaceStore } from './face.store.js';

class MemoryFaceStore implements FaceStore {
  consents: FaceConsentRecord[] = [];
  templates: { employeeId: string; embeddingEncrypted: string }[] = [];

  async latestConsent(employeeId: string) {
    return [...this.consents].filter((c) => c.employeeId === employeeId).sort((a, b) => b.acceptedAt.getTime() - a.acceptedAt.getTime())[0] ?? null;
  }
  async addConsent(employeeId: string, version: string) {
    const c = { id: String(this.consents.length + 1), employeeId, version, acceptedAt: new Date(), revokedAt: null };
    this.consents.push(c);
    return c;
  }
  async revokeConsent(employeeId: string) {
    for (const c of this.consents) if (c.employeeId === employeeId && !c.revokedAt) c.revokedAt = new Date();
  }
  async listTemplates(employeeId: string) {
    return this.templates.filter((t) => t.employeeId === employeeId).map((t) => t.embeddingEncrypted);
  }
  async templateCount(employeeId: string) {
    return this.templates.filter((t) => t.employeeId === employeeId).length;
  }
  async replaceTemplates(employeeId: string, encrypted: string[]) {
    this.templates = this.templates.filter((t) => t.employeeId !== employeeId);
    for (const embeddingEncrypted of encrypted) this.templates.push({ employeeId, embeddingEncrypted });
  }
  async deleteTemplates(employeeId: string) {
    this.templates = this.templates.filter((t) => t.employeeId !== employeeId);
  }
}

class MemoryEmployeeStore implements EmployeeStore {
  rows: EmployeeRecord[] = [];
  async findById(id: string) { return this.rows.find((r) => r.id === id) ?? null; }
  async findByEmail(email: string) { return this.rows.find((r) => r.email === email) ?? null; }
  async findAll() { return this.rows; }
  async count() { return this.rows.length; }
  async add(e: Omit<EmployeeRecord, 'id' | 'active' | 'createdAt' | 'pinHash'>) {
    const row: EmployeeRecord = { ...e, id: 'emp-1', pinHash: null, active: true, createdAt: new Date() };
    this.rows.push(row);
    return row;
  }
  async save(e: EmployeeRecord) {
    this.rows = this.rows.map((r) => (r.id === e.id ? e : r));
    return e;
  }
}

const KEY = randomBytes(32).toString('base64');
const vec = (seed: number) => Array.from({ length: EMBEDDING_DIM }, (_, i) => Math.sin(seed + i));

function setup() {
  const employees = new MemoryEmployeeStore();
  employees.rows.push({
    id: 'emp-1', email: 'ana@test.local', passwordHash: 'x', pinHash: null, fullName: 'Ana', documentId: null,
    role: 'employee', active: true, createdAt: new Date(),
  });
  const faces = new MemoryFaceStore();
  return { faces, employees, service: new FaceService(faces, employees) };
}

describe('cifrado de embeddings', () => {
  it('ida y vuelta exacta con la clave correcta', () => {
    const key = Buffer.from(KEY, 'base64');
    const v = normalize(vec(1));
    const back = decryptEmbedding(encryptEmbedding(v, key), key);
    expect(back.length).toBe(EMBEDDING_DIM);
    back.forEach((x, i) => expect(x).toBeCloseTo(v[i]!, 6));
  });

  it('detecta manipulación del texto cifrado (GCM)', () => {
    const key = Buffer.from(KEY, 'base64');
    const enc = Buffer.from(encryptEmbedding(vec(2), key), 'base64');
    enc[enc.length - 1] ^= 0xff;
    expect(() => decryptEmbedding(enc.toString('base64'), key)).toThrow();
  });

  it('exige FACE_ENCRYPTION_KEY de 32 bytes', () => {
    expect(() => faceKey({})).toThrow(ServiceUnavailableException);
    expect(() => faceKey({ FACE_ENCRYPTION_KEY: 'corta' })).toThrow('32 bytes');
    expect(faceKey({ FACE_ENCRYPTION_KEY: KEY }).length).toBe(32);
  });
});

describe('FaceService', () => {
  const prev = process.env.FACE_ENCRYPTION_KEY;
  process.env.FACE_ENCRYPTION_KEY = KEY;

  it('no permite inscribirse sin consentimiento vigente', async () => {
    const { service } = setup();
    await expect(service.enroll('emp-1', [vec(1), vec(2), vec(3)], '1234')).rejects.toBeInstanceOf(ForbiddenException);
  });

  it('el consentimiento debe ser la versión vigente', async () => {
    const { service } = setup();
    await expect(service.giveConsent('emp-1', 'version-vieja')).rejects.toBeInstanceOf(ConflictException);
    const s = await service.giveConsent('emp-1', FACE_CONSENT_VERSION);
    expect(s.consented).toBe(true);
  });

  it('inscribe con 3 a 5 capturas, guarda solo texto cifrado y define el PIN', async () => {
    const { service, faces, employees } = setup();
    await service.giveConsent('emp-1', FACE_CONSENT_VERSION);

    await expect(service.enroll('emp-1', [vec(1), vec(2)], '1234')).rejects.toBeInstanceOf(BadRequestException);
    await expect(service.enroll('emp-1', [vec(1), vec(2), vec(3)].map((v) => v.slice(1)), '1234')).rejects.toBeInstanceOf(
      BadRequestException,
    );

    const s = await service.enroll('emp-1', [vec(1), vec(2), vec(3), vec(4)], '1234');
    expect(s.templates).toBe(4);
    expect(s.pinSet).toBe(true);
    // Lo guardado es texto cifrado que, descifrado, da el embedding normalizado (no la imagen).
    const back = decryptEmbedding(faces.templates[0]!.embeddingEncrypted, Buffer.from(KEY, 'base64'));
    back.forEach((x, i) => expect(x).toBeCloseTo(normalize(vec(1))[i]!, 6));
    expect(employees.rows[0]!.pinHash).toMatch(/^\$2[aby]\$/); // bcrypt, nunca el PIN en claro
  });

  it('revocar borra las plantillas y conserva el PIN', async () => {
    const { service } = setup();
    await service.giveConsent('emp-1', FACE_CONSENT_VERSION);
    await service.enroll('emp-1', [vec(1), vec(2), vec(3)], '1234');
    const s = await service.revoke('emp-1');
    expect(s.consented).toBe(false);
    expect(s.templates).toBe(0);
    expect(s.pinSet).toBe(true);
  });
});
