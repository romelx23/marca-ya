import { ConflictException, Inject, Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import bcrypt from 'bcryptjs';
import { Repository } from 'typeorm';
import { CreateEmployeeDto, UpdateEmployeeDto } from './employee.dto.js';
import { Employee } from './employee.entity.js';

export type PublicEmployee = Omit<Employee, 'passwordHash'>;

export function toPublic(e: Employee): PublicEmployee {
  const { passwordHash: _omit, ...rest } = e;
  return rest;
}

@Injectable()
export class EmployeesService {
  constructor(@InjectRepository(Employee) private readonly repo: Repository<Employee>) {}

  async create(dto: CreateEmployeeDto): Promise<PublicEmployee> {
    const email = dto.email.toLowerCase();
    if (await this.repo.findOne({ where: { email } })) {
      throw new ConflictException('Ya existe un empleado con ese correo');
    }
    const saved = await this.repo.save(
      this.repo.create({
        email,
        passwordHash: await bcrypt.hash(dto.password, 10),
        fullName: dto.fullName,
        documentId: dto.documentId ?? null,
        role: dto.role ?? 'employee',
      }),
    );
    return toPublic(saved);
  }

  async findAll(): Promise<PublicEmployee[]> {
    return (await this.repo.find({ order: { fullName: 'ASC' } })).map(toPublic);
  }

  async findOne(id: string): Promise<PublicEmployee> {
    const e = await this.repo.findOne({ where: { id } });
    if (!e) throw new NotFoundException('Empleado no encontrado');
    return toPublic(e);
  }

  findByEmail(email: string): Promise<Employee | null> {
    return this.repo.findOne({ where: { email: email.toLowerCase() } });
  }

  async update(id: string, dto: UpdateEmployeeDto): Promise<PublicEmployee> {
    const e = await this.repo.findOne({ where: { id } });
    if (!e) throw new NotFoundException('Empleado no encontrado');
    const { password, ...fields } = dto;
    Object.assign(e, fields);
    if (password) e.passwordHash = await bcrypt.hash(password, 10);
    return toPublic(await this.repo.save(e));
  }

  async count(): Promise<number> {
    return this.repo.count();
  }
}
