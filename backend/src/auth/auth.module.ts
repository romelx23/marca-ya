import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { EmployeesModule } from '../employees/employees.module.js';
import { AdminSeeder } from './admin.seeder.js';
import { AuthController } from './auth.controller.js';
import { AuthService } from './auth.service.js';

function jwtSecret(): string {
  const s = process.env.JWT_SECRET;
  if (s) return s;
  if (process.env.NODE_ENV === 'production') throw new Error('JWT_SECRET es obligatorio en producción');
  return 'dev-only-secret-change-me';
}

@Module({
  imports: [
    EmployeesModule,
    JwtModule.register({ global: true, secret: jwtSecret(), signOptions: { expiresIn: '8h' } }),
  ],
  controllers: [AuthController],
  providers: [AuthService, AdminSeeder],
})
export class AuthModule {}
