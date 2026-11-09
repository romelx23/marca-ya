import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Employee } from './employee.entity.js';
import { EMPLOYEE_STORE } from './employee.store.js';
import { EmployeesController } from './employees.controller.js';
import { EmployeesService } from './employees.service.js';
import { TypeOrmEmployeeStore } from './typeorm-employee.store.js';

@Module({
  imports: [TypeOrmModule.forFeature([Employee])],
  controllers: [EmployeesController],
  providers: [EmployeesService, { provide: EMPLOYEE_STORE, useClass: TypeOrmEmployeeStore }],
  exports: [EmployeesService],
})
export class EmployeesModule {}
