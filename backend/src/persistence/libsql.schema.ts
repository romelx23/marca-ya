import { Inject, Injectable, Logger, OnModuleInit } from '@nestjs/common';
import type { Client } from '@libsql/client';
import { LIBSQL_CLIENT } from './libsql.client.js';

/**
 * Esquema de Turso. Las mismas tablas que TypeORM, con tipos de SQLite:
 * las fechas se guardan como texto ISO-8601 en UTC (ordenan bien como texto)
 * y los booleanos como 0/1.
 */
const SCHEMA = [
  `CREATE TABLE IF NOT EXISTS employees (
    id TEXT PRIMARY KEY,
    email TEXT NOT NULL UNIQUE,
    passwordHash TEXT NOT NULL,
    fullName TEXT NOT NULL,
    documentId TEXT,
    role TEXT NOT NULL DEFAULT 'employee',
    active INTEGER NOT NULL DEFAULT 1,
    createdAt TEXT NOT NULL
  )`,
  `CREATE TABLE IF NOT EXISTS attendance_events (
    id TEXT PRIMARY KEY,
    employeeId TEXT NOT NULL,
    type TEXT NOT NULL,
    occurredAt TEXT NOT NULL,
    method TEXT NOT NULL DEFAULT 'app',
    deviceId TEXT,
    latitude REAL,
    longitude REAL,
    createdAt TEXT NOT NULL
  )`,
  `CREATE INDEX IF NOT EXISTS idx_attendance_employee_time ON attendance_events (employeeId, occurredAt)`,
  `CREATE TABLE IF NOT EXISTS device_tokens (
    id TEXT PRIMARY KEY,
    employeeId TEXT NOT NULL,
    token TEXT NOT NULL UNIQUE,
    platform TEXT NOT NULL,
    createdAt TEXT NOT NULL,
    lastSeenAt TEXT NOT NULL
  )`,
  `CREATE INDEX IF NOT EXISTS idx_device_tokens_employee ON device_tokens (employeeId)`,
  `CREATE TABLE IF NOT EXISTS face_consents (
    id TEXT PRIMARY KEY,
    employeeId TEXT NOT NULL,
    version TEXT NOT NULL,
    acceptedAt TEXT NOT NULL,
    revokedAt TEXT
  )`,
  `CREATE INDEX IF NOT EXISTS idx_face_consents_employee ON face_consents (employeeId, acceptedAt)`,
  `CREATE TABLE IF NOT EXISTS face_templates (
    id TEXT PRIMARY KEY,
    employeeId TEXT NOT NULL,
    embeddingEncrypted TEXT NOT NULL,
    createdAt TEXT NOT NULL
  )`,
  `CREATE INDEX IF NOT EXISTS idx_face_templates_employee ON face_templates (employeeId)`,
];

/** Columnas añadidas después de crear las tablas. Turso ya tiene tablas antiguas, así que se agregan si faltan. */
const ADDED_COLUMNS: { table: string; column: string; ddl: string }[] = [
  { table: 'employees', column: 'pinHash', ddl: 'ALTER TABLE employees ADD COLUMN pinHash TEXT' },
];

/** Crea las tablas al arrancar si no existen. Sustituye a `synchronize` de TypeORM para Turso. */
@Injectable()
export class LibsqlSchema implements OnModuleInit {
  private readonly log = new Logger('LibsqlSchema');

  constructor(@Inject(LIBSQL_CLIENT) private readonly client: Client) {}

  async onModuleInit() {
    await this.client.batch(SCHEMA, 'write');
    for (const { table, column, ddl } of ADDED_COLUMNS) {
      const rs = await this.client.execute(`PRAGMA table_info(${table})`);
      const present = rs.rows.some((r) => r.name === column);
      if (!present) {
        await this.client.execute(ddl);
        this.log.log(`Columna añadida: ${table}.${column}`);
      }
    }
    this.log.log('Esquema de Turso listo');
  }
}
