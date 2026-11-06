import { Inject, Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import bcrypt from 'bcryptjs';
import { EmployeesService, toPublic } from '../employees/employees.service.js';

@Injectable()
export class AuthService {
  constructor(
    @Inject(EmployeesService) private readonly employees: EmployeesService,
    @Inject(JwtService) private readonly jwt: JwtService,
  ) {}

  async login(email: string, password: string) {
    const e = await this.employees.findByEmail(email);
    // Misma respuesta para correo inexistente, clave errónea o cuenta inactiva.
    if (!e || !e.active || !(await bcrypt.compare(password, e.passwordHash))) {
      throw new UnauthorizedException('Credenciales inválidas');
    }
    const accessToken = await this.jwt.signAsync({ sub: e.id, role: e.role });
    return { accessToken, employee: toPublic(e) };
  }
}
