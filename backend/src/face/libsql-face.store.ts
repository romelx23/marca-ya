import { randomUUID } from 'node:crypto';
import type { Client } from '@libsql/client';
import { date, nullableStr, rowsOf, str } from '../persistence/libsql.rows.js';
import type { FaceConsentRecord, FaceStore } from './face.store.js';

function toConsent(r: Record<string, unknown>): FaceConsentRecord {
  return {
    id: str(r.id),
    employeeId: str(r.employeeId),
    version: str(r.version),
    acceptedAt: date(r.acceptedAt),
    revokedAt: nullableStr(r.revokedAt) === null ? null : date(r.revokedAt),
  };
}

/** Adaptador de FaceStore para Turso (libSQL). Las plantillas se reemplazan en un solo batch atómico. */
export class LibsqlFaceStore implements FaceStore {
  constructor(private readonly client: Client) {}

  async latestConsent(employeeId: string): Promise<FaceConsentRecord | null> {
    const rs = await this.client.execute({
      sql: 'SELECT id, employeeId, version, acceptedAt, revokedAt FROM face_consents WHERE employeeId = ? ORDER BY acceptedAt DESC LIMIT 1',
      args: [employeeId],
    });
    return rowsOf(rs).map(toConsent)[0] ?? null;
  }

  async addConsent(employeeId: string, version: string): Promise<FaceConsentRecord> {
    const record: FaceConsentRecord = { id: randomUUID(), employeeId, version, acceptedAt: new Date(), revokedAt: null };
    await this.client.execute({
      sql: 'INSERT INTO face_consents (id, employeeId, version, acceptedAt, revokedAt) VALUES (?, ?, ?, ?, NULL)',
      args: [record.id, employeeId, version, record.acceptedAt.toISOString()],
    });
    return record;
  }

  async revokeConsent(employeeId: string): Promise<void> {
    await this.client.execute({
      sql: 'UPDATE face_consents SET revokedAt = ? WHERE employeeId = ? AND revokedAt IS NULL',
      args: [new Date().toISOString(), employeeId],
    });
  }

  async templateCount(employeeId: string): Promise<number> {
    const rs = await this.client.execute({
      sql: 'SELECT COUNT(*) AS n FROM face_templates WHERE employeeId = ?',
      args: [employeeId],
    });
    return Number(rowsOf(rs)[0]?.n ?? 0);
  }

  async listTemplates(employeeId: string): Promise<string[]> {
    const rs = await this.client.execute({
      sql: 'SELECT embeddingEncrypted FROM face_templates WHERE employeeId = ? ORDER BY createdAt ASC',
      args: [employeeId],
    });
    return rowsOf(rs).map((r) => str(r.embeddingEncrypted));
  }

  async replaceTemplates(employeeId: string, encryptedEmbeddings: string[]): Promise<void> {
    const now = new Date().toISOString();
    await this.client.batch(
      [
        { sql: 'DELETE FROM face_templates WHERE employeeId = ?', args: [employeeId] },
        ...encryptedEmbeddings.map((embedding) => ({
          sql: 'INSERT INTO face_templates (id, employeeId, embeddingEncrypted, createdAt) VALUES (?, ?, ?, ?)',
          args: [randomUUID(), employeeId, embedding, now],
        })),
      ],
      'write',
    );
  }

  async deleteTemplates(employeeId: string): Promise<void> {
    await this.client.execute({ sql: 'DELETE FROM face_templates WHERE employeeId = ?', args: [employeeId] });
  }
}
