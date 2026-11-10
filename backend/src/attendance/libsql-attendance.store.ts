import { randomUUID } from 'node:crypto';
import type { Client } from '@libsql/client';
import { date, nullableNum, nullableStr, rowsOf, str } from '../persistence/libsql.rows.js';
import type { AttendanceMethod, AttendanceRecord, AttendanceStore, AttendanceType, NewAttendance } from './attendance.store.js';

const COLUMNS = 'id, employeeId, type, occurredAt, method, deviceId, latitude, longitude, createdAt';

function toRecord(r: Record<string, unknown>): AttendanceRecord {
  return {
    id: str(r.id),
    employeeId: str(r.employeeId),
    type: str(r.type) as AttendanceType,
    occurredAt: date(r.occurredAt),
    method: str(r.method) as AttendanceMethod,
    deviceId: nullableStr(r.deviceId),
    latitude: nullableNum(r.latitude),
    longitude: nullableNum(r.longitude),
    createdAt: date(r.createdAt),
  };
}

/**
 * Adaptador de AttendanceStore para Turso. Las fechas son texto ISO en UTC con milisegundos,
 * así que la comparación `occurredAt >= ?` por texto equivale a la comparación por tiempo.
 */
export class LibsqlAttendanceStore implements AttendanceStore {
  constructor(private readonly client: Client) {}

  async find(query: { employeeId?: string; from: Date; to: Date }): Promise<AttendanceRecord[]> {
    const args: (string | number)[] = [query.from.toISOString(), query.to.toISOString()];
    let sql = `SELECT ${COLUMNS} FROM attendance_events WHERE occurredAt >= ? AND occurredAt < ?`;
    if (query.employeeId) {
      sql += ' AND employeeId = ?';
      args.push(query.employeeId);
    }
    sql += ' ORDER BY occurredAt ASC';
    const rs = await this.client.execute({ sql, args });
    return rowsOf(rs).map(toRecord);
  }

  async add(event: NewAttendance): Promise<AttendanceRecord> {
    const record: AttendanceRecord = { ...event, id: randomUUID(), createdAt: new Date() };
    await this.client.execute({
      sql: `INSERT INTO attendance_events (${COLUMNS}) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      args: [
        record.id,
        record.employeeId,
        record.type,
        record.occurredAt.toISOString(),
        record.method,
        record.deviceId,
        record.latitude,
        record.longitude,
        record.createdAt.toISOString(),
      ],
    });
    return record;
  }
}
