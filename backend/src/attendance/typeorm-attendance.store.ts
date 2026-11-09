import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { And, FindOptionsWhere, LessThan, MoreThanOrEqual, Repository } from 'typeorm';
import { AttendanceEvent } from './attendance.entity.js';
import type { AttendanceRecord, AttendanceStore, NewAttendance } from './attendance.store.js';

/** Adaptador de AttendanceStore con TypeORM (PostgreSQL o sql.js según DB_HOST). */
@Injectable()
export class TypeOrmAttendanceStore implements AttendanceStore {
  constructor(@InjectRepository(AttendanceEvent) private readonly repo: Repository<AttendanceEvent>) {}

  find(query: { employeeId?: string; from: Date; to: Date }): Promise<AttendanceRecord[]> {
    const where: FindOptionsWhere<AttendanceEvent> = {
      occurredAt: And(MoreThanOrEqual(query.from), LessThan(query.to)),
      ...(query.employeeId ? { employeeId: query.employeeId } : {}),
    };
    return this.repo.find({ where, order: { occurredAt: 'ASC' } });
  }

  add(event: NewAttendance): Promise<AttendanceRecord> {
    return this.repo.save(this.repo.create(event));
  }
}
