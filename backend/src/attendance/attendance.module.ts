import { Module } from '@nestjs/common';
import { EmployeesModule } from '../employees/employees.module.js';
import { FaceModule } from '../face/face.module.js';
import { AttendanceController } from './attendance.controller.js';
import { AttendanceService } from './attendance.service.js';

@Module({
  imports: [EmployeesModule, FaceModule],
  controllers: [AttendanceController],
  providers: [AttendanceService],
  exports: [AttendanceService],
})
export class AttendanceModule {}
