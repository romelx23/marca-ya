import { randomUUID } from 'node:crypto';
import type { Client } from '@libsql/client';
import { bool, date, rowsOf, str } from '../persistence/libsql.rows.js';
import type { EmployeeRecord, EmployeeStore, NewEmployee, Role } from './employee.store.js';

const COLUMNS = 'id, email, passwordHash, pinHash, fullName, documentId, role, active, createdAt';

function toRecord(r: Record<string, unknown>): EmployeeRecord {
  return {
    id: str(r.id),
    email: str(r.email),
    passwordHash: str(r.passwordHash),
    pinHash: r.pinHash == null ? null : str(r.pinHash),
    fullName: str(r.fullName),
    documentId: r.documentId == null ? null : str(r.documentId),
    role: str(r.role) as Role,
    active: bool(r.active),
    createdAt: date(r.createdAt),
  };
}

/** Adaptador de EmployeeStore para Turso (libSQL), con SQL directo. */
export class LibsqlEmployeeStore implements EmployeeStore {
  constructor(private readonly client: Client) {}

  async findById(id: string): Promise<EmployeeRecord | null> {
    const rs = await this.client.execute({ sql: `SELECT ${COLUMNS} FROM employees WHERE id = ?`, args: [id] });
    return rowsOf(rs).map(toRecord)[0] ?? null;
  }

  async findByEmail(email: string): Promise<EmployeeRecord | null> {
    const rs = await this.client.execute({ sql: `SELECT ${COLUMNS} FROM employees WHERE email = ?`, args: [email] });
    return rowsOf(rs).map(toRecord)[0] ?? null;
  }

  async findAll(): Promise<EmployeeRecord[]> {
    const rs = await this.client.execute(`SELECT ${COLUMNS} FROM employees ORDER BY fullName ASC`);
    return rowsOf(rs).map(toRecord);
  }

  async count(): Promise<number> {
    const rs = await this.client.execute('SELECT COUNT(*) AS n FROM employees');
    return Number(rowsOf(rs)[0]?.n ?? 0);
  }

  async add(e: NewEmployee): Promise<EmployeeRecord> {
    const record: EmployeeRecord = { ...e, id: randomUUID(), pinHash: null, active: true, createdAt: new Date() };
    await this.client.execute({
      sql: `INSERT INTO employees (${COLUMNS}) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      args: [
        record.id,
        record.email,
        record.passwordHash,
        null,
        record.fullName,
        record.documentId,
        record.role,
        1,
        record.createdAt.toISOString(),
      ],
    });
    return record;
  }

  async save(e: EmployeeRecord): Promise<EmployeeRecord> {
    await this.client.execute({
      sql: 'UPDATE employees SET email = ?, passwordHash = ?, pinHash = ?, fullName = ?, documentId = ?, role = ?, active = ? WHERE id = ?',
      args: [e.email, e.passwordHash, e.pinHash, e.fullName, e.documentId, e.role, e.active ? 1 : 0, e.id],
    });
    return e;
  }
}
