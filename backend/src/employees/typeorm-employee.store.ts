import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Employee } from './employee.entity.js';
import type { EmployeeRecord, EmployeeStore, NewEmployee } from './employee.store.js';

/** Adaptador de EmployeeStore con TypeORM (PostgreSQL o sql.js según DB_HOST). */
@Injectable()
export class TypeOrmEmployeeStore implements EmployeeStore {
  constructor(@InjectRepository(Employee) private readonly repo: Repository<Employee>) {}

  findById(id: string): Promise<EmployeeRecord | null> {
    return this.repo.findOne({ where: { id } });
  }

  findByEmail(email: string): Promise<EmployeeRecord | null> {
    return this.repo.findOne({ where: { email } });
  }

  findAll(): Promise<EmployeeRecord[]> {
    return this.repo.find({ order: { fullName: 'ASC' } });
  }

  count(): Promise<number> {
    return this.repo.count();
  }

  add(employee: NewEmployee): Promise<EmployeeRecord> {
    return this.repo.save(this.repo.create(employee));
  }

  save(employee: EmployeeRecord): Promise<EmployeeRecord> {
    return this.repo.save(employee);
  }
}
