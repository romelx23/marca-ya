import { Global, Module, type DynamicModule } from '@nestjs/common';
import { TypeOrmModule, getRepositoryToken } from '@nestjs/typeorm';
import type { Client } from '@libsql/client';
import type { Repository } from 'typeorm';
import { ATTENDANCE_STORE } from '../attendance/attendance.store.js';
import { TypeOrmAttendanceStore } from '../attendance/typeorm-attendance.store.js';
import { AttendanceEvent } from '../attendance/attendance.entity.js';
import { LibsqlAttendanceStore } from '../attendance/libsql-attendance.store.js';
import { Employee } from '../employees/employee.entity.js';
import { EMPLOYEE_STORE } from '../employees/employee.store.js';
import { TypeOrmEmployeeStore } from '../employees/typeorm-employee.store.js';
import { LibsqlEmployeeStore } from '../employees/libsql-employee.store.js';
import { DeviceToken } from '../notifications/device-token.entity.js';
import { DEVICE_STORE } from '../notifications/device.store.js';
import { TypeOrmDeviceStore } from '../notifications/typeorm-device.store.js';
import { LibsqlDeviceStore } from '../notifications/libsql-device.store.js';
import { FACE_STORE } from '../face/face.store.js';
import { FaceConsent } from '../face/face-consent.entity.js';
import { FaceTemplate } from '../face/face-template.entity.js';
import { TypeOrmFaceStore } from '../face/typeorm-face.store.js';
import { LibsqlFaceStore } from '../face/libsql-face.store.js';
import { LIBSQL_CLIENT, createLibsqlClient } from './libsql.client.js';
import { LibsqlSchema } from './libsql.schema.js';
import { ENTITIES, typeOrmOptions } from './typeorm.options.js';

export type DbProvider = 'turso' | 'postgres' | 'sqljs';

/**
 * Elige la base de datos. `DB_PROVIDER` tiene prioridad; si no está, se decide por las variables:
 * TURSO_DATABASE_URL → turso; DB_HOST → postgres; si no hay nada → sqljs (memoria, solo pruebas).
 */
export function chooseDbProvider(env = process.env): DbProvider {
  const explicit = env.DB_PROVIDER;
  if (explicit) {
    if (explicit !== 'turso' && explicit !== 'postgres' && explicit !== 'sqljs') {
      throw new Error(`DB_PROVIDER desconocido: "${explicit}" (usa turso, postgres o sqljs)`);
    }
    return explicit;
  }
  if (env.TURSO_DATABASE_URL) return 'turso';
  if (env.DB_HOST) return 'postgres';
  return 'sqljs';
}

const STORE_TOKENS = [EMPLOYEE_STORE, ATTENDANCE_STORE, DEVICE_STORE, FACE_STORE];

/**
 * Proporciona los puertos de persistencia a toda la aplicación. Los módulos de dominio
 * solo inyectan los tokens; qué adaptador hay detrás lo decide esta configuración.
 */
@Global()
@Module({})
export class PersistenceModule {
  static forRoot(env = process.env): DynamicModule {
    if (chooseDbProvider(env) === 'turso') {
      return {
        module: PersistenceModule,
        providers: [
          { provide: LIBSQL_CLIENT, useFactory: (): Client => createLibsqlClient(env) },
          { provide: EMPLOYEE_STORE, useFactory: (c: Client) => new LibsqlEmployeeStore(c), inject: [LIBSQL_CLIENT] },
          { provide: ATTENDANCE_STORE, useFactory: (c: Client) => new LibsqlAttendanceStore(c), inject: [LIBSQL_CLIENT] },
          { provide: DEVICE_STORE, useFactory: (c: Client) => new LibsqlDeviceStore(c), inject: [LIBSQL_CLIENT] },
          { provide: FACE_STORE, useFactory: (c: Client) => new LibsqlFaceStore(c), inject: [LIBSQL_CLIENT] },
          LibsqlSchema,
        ],
        exports: STORE_TOKENS,
      };
    }

    return {
      module: PersistenceModule,
      imports: [TypeOrmModule.forRoot(typeOrmOptions(env)), TypeOrmModule.forFeature(ENTITIES)],
      providers: [
        {
          provide: EMPLOYEE_STORE,
          useFactory: (r: Repository<Employee>) => new TypeOrmEmployeeStore(r),
          inject: [getRepositoryToken(Employee)],
        },
        {
          provide: ATTENDANCE_STORE,
          useFactory: (r: Repository<AttendanceEvent>) => new TypeOrmAttendanceStore(r),
          inject: [getRepositoryToken(AttendanceEvent)],
        },
        {
          provide: DEVICE_STORE,
          useFactory: (r: Repository<DeviceToken>) => new TypeOrmDeviceStore(r),
          inject: [getRepositoryToken(DeviceToken)],
        },
        {
          provide: FACE_STORE,
          useFactory: (c: Repository<FaceConsent>, t: Repository<FaceTemplate>) => new TypeOrmFaceStore(c, t),
          inject: [getRepositoryToken(FaceConsent), getRepositoryToken(FaceTemplate)],
        },
      ],
      exports: STORE_TOKENS,
    };
  }
}
