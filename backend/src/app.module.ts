import { Module } from '@nestjs/common';
import { AttendanceModule } from './attendance/attendance.module.js';
import { AuthModule } from './auth/auth.module.js';
import { EmployeesModule } from './employees/employees.module.js';
import { FaceModule } from './face/face.module.js';
import { NotificationsModule } from './notifications/notifications.module.js';
import { PersistenceModule } from './persistence/persistence.module.js';

@Module({
  imports: [PersistenceModule.forRoot(), EmployeesModule, AuthModule, AttendanceModule, NotificationsModule, FaceModule],
})
export class AppModule {}
