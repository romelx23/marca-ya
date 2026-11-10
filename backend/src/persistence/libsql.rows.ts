import type { ResultSet } from '@libsql/client';

/** Filas de un ResultSet como objetos planos. */
export function rowsOf(rs: ResultSet): Record<string, unknown>[] {
  return rs.rows as unknown as Record<string, unknown>[];
}

export const str = (v: unknown): string => String(v);
export const nullableStr = (v: unknown): string | null => (v === null || v === undefined ? null : String(v));
export const nullableNum = (v: unknown): number | null => (v === null || v === undefined ? null : Number(v));
export const bool = (v: unknown): boolean => Number(v) === 1;
export const date = (v: unknown): Date => new Date(String(v));
