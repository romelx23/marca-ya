import { Module } from '@nestjs/common';
import { TypeOrmModule, type TypeOrmModuleOptions } from '@nestjs/typeorm';
import { AttendanceEvent } from './attendance/attendance.entity.js';
import { AttendanceModule } from './attendance/attendance.module.js';
import { AuthModule } from './auth/auth.module.js';
import { Employee } from './employees/employee.entity.js';
import { EmployeesModule } from './employees/employees.module.js';

const entities = [Employee, AttendanceEvent];

// Postgres si hay DB_HOST; si no, sql.js (sin instalación) para desarrollo y tests.
const database: TypeOrmModuleOptions = process.env.DB_HOST
  ? {
      type: 'postgres',
      host: process.env.DB_HOST,
      port: Number(process.env.DB_PORT ?? 5432),
      username: process.env.DB_USER,
      password: process.env.DB_PASSWORD,
      database: process.env.DB_NAME,
      entities,
      synchronize: process.env.NODE_ENV !== 'production',
    }
  : { type: 'sqljs', entities, synchronize: true };

@Module({
  imports: [TypeOrmModule.forRoot(database), EmployeesModule, AuthModule, AttendanceModule],
})
export class AppModule {}
