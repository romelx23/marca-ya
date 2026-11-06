import { Body, Controller, Get, Inject, Param, Patch, Post, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard.js';
import { Roles } from '../auth/roles.decorator.js';
import { RolesGuard } from '../auth/roles.guard.js';
import { CreateEmployeeDto, UpdateEmployeeDto } from './employee.dto.js';
import { EmployeesService } from './employees.service.js';

@Controller('employees')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('hr', 'admin')
export class EmployeesController {
  constructor(@Inject(EmployeesService) private readonly service: EmployeesService) {}

  @Post()
  create(@Body() dto: CreateEmployeeDto) {
    return this.service.create(dto);
  }

  @Get()
  findAll() {
    return this.service.findAll();
  }

  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.service.findOne(id);
  }

  @Patch(':id')
  update(@Param('id') id: string, @Body() dto: UpdateEmployeeDto) {
    return this.service.update(id, dto);
  }
}
