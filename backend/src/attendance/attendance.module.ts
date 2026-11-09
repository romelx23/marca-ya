import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { EmployeesModule } from '../employees/employees.module.js';
import { AttendanceController } from './attendance.controller.js';
import { AttendanceEvent } from './attendance.entity.js';
import { ATTENDANCE_STORE } from './attendance.store.js';
import { AttendanceService } from './attendance.service.js';
import { TypeOrmAttendanceStore } from './typeorm-attendance.store.js';

@Module({
  imports: [TypeOrmModule.forFeature([AttendanceEvent]), EmployeesModule],
  controllers: [AttendanceController],
  providers: [AttendanceService, { provide: ATTENDANCE_STORE, useClass: TypeOrmAttendanceStore }],
  exports: [AttendanceService],
})
export class AttendanceModule {}
