import { createClient, type Client } from '@libsql/client';

export const LIBSQL_CLIENT = Symbol('LIBSQL_CLIENT');

/** Cliente de Turso (libSQL). Acepta `libsql://…` con token, o `file:ruta.db` para pruebas locales. */
export function createLibsqlClient(env = process.env): Client {
  const url = env.TURSO_DATABASE_URL;
  if (!url) throw new Error('Falta TURSO_DATABASE_URL para usar Turso');
  return createClient({ url, authToken: env.TURSO_AUTH_TOKEN || undefined });
}
