import { Inject, Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { EmployeesService } from '../employees/employees.service.js';

/** Crea el primer administrador si la tabla está vacía (ADMIN_EMAIL / ADMIN_PASSWORD). */
@Injectable()
export class AdminSeeder implements OnModuleInit {
  private readonly log = new Logger(AdminSeeder.name);
  constructor(@Inject(EmployeesService) private readonly employees: EmployeesService) {}

  async onModuleInit() {
    if ((await this.employees.count()) > 0) return;
    const email = process.env.ADMIN_EMAIL;
    const password = process.env.ADMIN_PASSWORD;
    if (!email || !password) {
      this.log.warn('Sin empleados y sin ADMIN_EMAIL/ADMIN_PASSWORD: no se creó administrador');
      return;
    }
    await this.employees.create({ email, password, fullName: 'Administrador', role: 'admin' });
    this.log.log(`Administrador inicial creado: ${email}`);
  }
}
