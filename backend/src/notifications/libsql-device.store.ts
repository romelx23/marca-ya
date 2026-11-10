import { randomUUID } from 'node:crypto';
import type { Client } from '@libsql/client';
import { date, rowsOf, str } from '../persistence/libsql.rows.js';
import type { DevicePlatform, DeviceRecord, DeviceStore } from './device.store.js';

const COLUMNS = 'id, employeeId, token, platform, createdAt, lastSeenAt';

function toRecord(r: Record<string, unknown>): DeviceRecord {
  return {
    id: str(r.id),
    employeeId: str(r.employeeId),
    token: str(r.token),
    platform: str(r.platform) as DevicePlatform,
    createdAt: date(r.createdAt),
    lastSeenAt: date(r.lastSeenAt),
  };
}

/** Adaptador de DeviceStore para Turso (libSQL), con SQL directo. */
export class LibsqlDeviceStore implements DeviceStore {
  constructor(private readonly client: Client) {}

  async findByToken(token: string): Promise<DeviceRecord | null> {
    const rs = await this.client.execute({ sql: `SELECT ${COLUMNS} FROM device_tokens WHERE token = ?`, args: [token] });
    return rowsOf(rs).map(toRecord)[0] ?? null;
  }

  async findByEmployee(employeeId: string): Promise<DeviceRecord[]> {
    const rs = await this.client.execute({
      sql: `SELECT ${COLUMNS} FROM device_tokens WHERE employeeId = ?`,
      args: [employeeId],
    });
    return rowsOf(rs).map(toRecord);
  }

  async add(device: { employeeId: string; token: string; platform: DevicePlatform }): Promise<DeviceRecord> {
    const now = new Date();
    const record: DeviceRecord = { ...device, id: randomUUID(), createdAt: now, lastSeenAt: now };
    await this.client.execute({
      sql: `INSERT INTO device_tokens (${COLUMNS}) VALUES (?, ?, ?, ?, ?, ?)`,
      args: [record.id, record.employeeId, record.token, record.platform, now.toISOString(), now.toISOString()],
    });
    return record;
  }

  async save(device: DeviceRecord): Promise<DeviceRecord> {
    const lastSeenAt = new Date();
    await this.client.execute({
      sql: 'UPDATE device_tokens SET employeeId = ?, platform = ?, lastSeenAt = ? WHERE id = ?',
      args: [device.employeeId, device.platform, lastSeenAt.toISOString(), device.id],
    });
    return { ...device, lastSeenAt };
  }

  async removeByEmployeeAndToken(employeeId: string, token: string): Promise<void> {
    await this.client.execute({
      sql: 'DELETE FROM device_tokens WHERE employeeId = ? AND token = ?',
      args: [employeeId, token],
    });
  }

  async removeTokens(tokens: string[]): Promise<void> {
    if (tokens.length === 0) return;
    const marks = tokens.map(() => '?').join(', ');
    await this.client.execute({ sql: `DELETE FROM device_tokens WHERE token IN (${marks})`, args: tokens });
  }
}
