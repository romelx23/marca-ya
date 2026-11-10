import type { TypeOrmModuleOptions } from '@nestjs/typeorm';
import { AttendanceEvent } from '../attendance/attendance.entity.js';
import { Employee } from '../employees/employee.entity.js';
import { FaceConsent } from '../face/face-consent.entity.js';
import { FaceTemplate } from '../face/face-template.entity.js';
import { DeviceToken } from '../notifications/device-token.entity.js';

export const ENTITIES = [Employee, AttendanceEvent, DeviceToken, FaceConsent, FaceTemplate];

/** Configuración de TypeORM para PostgreSQL (con DB_HOST) o sql.js en memoria (sin DB_HOST). */
export function typeOrmOptions(env = process.env): TypeOrmModuleOptions {
  return env.DB_HOST
    ? {
        type: 'postgres',
        host: env.DB_HOST,
        port: Number(env.DB_PORT ?? 5432),
        username: env.DB_USER,
        password: env.DB_PASSWORD,
        database: env.DB_NAME,
        entities: ENTITIES,
        synchronize: env.NODE_ENV !== 'production',
      }
    : { type: 'sqljs', entities: ENTITIES, synchronize: true };
}
