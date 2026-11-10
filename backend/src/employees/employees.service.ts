import { ConflictException, Inject, Injectable, NotFoundException } from '@nestjs/common';
import bcrypt from 'bcryptjs';
import { CreateEmployeeDto, UpdateEmployeeDto } from './employee.dto.js';
import { EMPLOYEE_STORE, type EmployeeRecord, type EmployeeStore } from './employee.store.js';

export type PublicEmployee = Omit<EmployeeRecord, 'passwordHash' | 'pinHash'>;

/** Nunca expone los hashes de clave ni de PIN. */
export function toPublic(e: EmployeeRecord): PublicEmployee {
  const { passwordHash: _omit, pinHash: _omitPin, ...rest } = e;
  return rest;
}

@Injectable()
export class EmployeesService {
  constructor(@Inject(EMPLOYEE_STORE) private readonly store: EmployeeStore) {}

  async create(dto: CreateEmployeeDto): Promise<PublicEmployee> {
    const email = dto.email.toLowerCase();
    if (await this.store.findByEmail(email)) {
      throw new ConflictException('Ya existe un empleado con ese correo');
    }
    const saved = await this.store.add({
      email,
      passwordHash: await bcrypt.hash(dto.password, 10),
      fullName: dto.fullName,
      documentId: dto.documentId ?? null,
      role: dto.role ?? 'employee',
    });
    return toPublic(saved);
  }

  async findAll(): Promise<PublicEmployee[]> {
    return (await this.store.findAll()).map(toPublic);
  }

  async findOne(id: string): Promise<PublicEmployee> {
    const e = await this.store.findById(id);
    if (!e) throw new NotFoundException('Empleado no encontrado');
    return toPublic(e);
  }

  findByEmail(email: string): Promise<EmployeeRecord | null> {
    return this.store.findByEmail(email.toLowerCase());
  }

  async update(id: string, dto: UpdateEmployeeDto): Promise<PublicEmployee> {
    const e = await this.store.findById(id);
    if (!e) throw new NotFoundException('Empleado no encontrado');
    const { password, ...fields } = dto;
    // El DTO trae como `undefined` los campos no enviados: solo se copian los que llegaron.
    Object.assign(e, Object.fromEntries(Object.entries(fields).filter(([, v]) => v !== undefined)));
    if (password) e.passwordHash = await bcrypt.hash(password, 10);
    return toPublic(await this.store.save(e));
  }

  /** Comprueba el PIN de respaldo. Falso si el empleado no tiene PIN definido. */
  async verifyPin(id: string, pin: string): Promise<boolean> {
    const e = await this.store.findById(id);
    if (!e || !e.pinHash) return false;
    return bcrypt.compare(pin, e.pinHash);
  }

  async count(): Promise<number> {
    return this.store.count();
  }
}
