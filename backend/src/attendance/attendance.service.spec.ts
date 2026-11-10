import { ConflictException } from '@nestjs/common';
import { describe, expect, it } from 'vitest';
import type { EmployeesService } from '../employees/employees.service.js';
import type { FaceMatchService } from '../face/face-match.service.js';
import { AttendanceService } from './attendance.service.js';
import type { AttendanceRecord, AttendanceStore, NewAttendance } from './attendance.store.js';

/** Almacén en memoria: prueba que la lógica de marcaciones no depende de ninguna base de datos. */
class MemoryAttendanceStore implements AttendanceStore {
  private rows: AttendanceRecord[] = [];

  async find(q: { employeeId?: string; from: Date; to: Date }) {
    return this.rows
      .filter((r) => (!q.employeeId || r.employeeId === q.employeeId) && r.occurredAt >= q.from && r.occurredAt < q.to)
      .sort((a, b) => a.occurredAt.getTime() - b.occurredAt.getTime());
  }

  async add(e: NewAttendance) {
    const row: AttendanceRecord = { ...e, id: String(this.rows.length + 1), createdAt: new Date() };
    this.rows.push(row);
    return row;
  }
}

const noEmployees = { findAll: async () => [] } as unknown as EmployeesService;
const noFace = {} as unknown as FaceMatchService;
const at = (iso: string) => new Date(iso);

describe('AttendanceService con un almacén en memoria', () => {
  it('alterna entrada y salida, rechaza duplicadas y calcula las horas', async () => {
    const service = new AttendanceService(new MemoryAttendanceStore(), noEmployees, noFace);
    const emp = 'emp-1';

    // 10:00 y 12:30 en Lima (UTC-5).
    await service.mark(emp, { type: 'in' }, { now: at('2026-11-05T15:00:00Z') });
    await expect(service.mark(emp, { type: 'in' }, { now: at('2026-11-05T15:05:00Z') })).rejects.toBeInstanceOf(
      ConflictException,
    );
    await service.mark(emp, { type: 'out' }, { now: at('2026-11-05T17:30:00Z') });

    const day = await service.today(emp, at('2026-11-05T18:00:00Z'));
    expect(day.checkedIn).toBe(false);
    expect(day.events).toHaveLength(2);
    expect(day.workedSeconds).toBe(2.5 * 3600);
  });

  it('una entrada abierta cuenta hasta el momento de la consulta', async () => {
    const service = new AttendanceService(new MemoryAttendanceStore(), noEmployees, noFace);
    await service.mark('emp-2', { type: 'in' }, { now: at('2026-11-05T15:00:00Z') });
    const day = await service.today('emp-2', at('2026-11-05T16:00:00Z'));
    expect(day.checkedIn).toBe(true);
    expect(day.workedSeconds).toBe(3600);
  });

  it('el rango filtra por empleado y por días locales', async () => {
    const store = new MemoryAttendanceStore();
    const service = new AttendanceService(store, noEmployees, noFace);
    await service.mark('a', { type: 'in' }, { now: at('2026-11-05T15:00:00Z') });
    await service.mark('b', { type: 'in' }, { now: at('2026-11-05T15:00:00Z') });
    await service.mark('a', { type: 'out' }, { now: at('2026-11-05T16:00:00Z') });

    const onlyA = await service.range({ from: '2026-11-05', to: '2026-11-05', employeeId: 'a' }, at('2026-11-05T20:00:00Z'));
    expect(onlyA.map((e) => e.type)).toEqual(['in', 'out']);

    const everyone = await service.range({ from: '2026-11-05', to: '2026-11-05' }, at('2026-11-05T20:00:00Z'));
    expect(everyone).toHaveLength(3);
  });
});
