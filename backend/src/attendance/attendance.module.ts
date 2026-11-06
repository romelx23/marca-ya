import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { EmployeesModule } from '../employees/employees.module.js';
import { AttendanceController } from './attendance.controller.js';
import { AttendanceEvent } from './attendance.entity.js';
import { AttendanceService } from './attendance.service.js';

@Module({
  imports: [TypeOrmModule.forFeature([AttendanceEvent]), EmployeesModule],
  controllers: [AttendanceController],
  providers: [AttendanceService],
  exports: [AttendanceService],
})
export class AttendanceModule {}
