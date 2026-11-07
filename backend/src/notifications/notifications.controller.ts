import { Body, Controller, Delete, HttpCode, Inject, Param, Post, Req, UseGuards } from '@nestjs/common';
import { JwtAuthGuard, type AuthUser } from '../auth/jwt-auth.guard.js';
import { Roles } from '../auth/roles.decorator.js';
import { RolesGuard } from '../auth/roles.guard.js';
import { RegisterDeviceDto, SendNotificationDto } from './notifications.dto.js';
import { NotificationsService } from './notifications.service.js';

@Controller()
@UseGuards(JwtAuthGuard, RolesGuard)
export class NotificationsController {
  constructor(@Inject(NotificationsService) private readonly service: NotificationsService) {}

  /** La app registra el token de FCM de su dispositivo tras iniciar sesión. */
  @Post('devices')
  @HttpCode(204)
  async register(@Req() req: { user: AuthUser }, @Body() dto: RegisterDeviceDto) {
    await this.service.register(req.user.sub, dto.token, dto.platform);
  }

  /** La app borra su token al cerrar sesión. */
  @Delete('devices/:token')
  @HttpCode(204)
  async unregister(@Req() req: { user: AuthUser }, @Param('token') token: string) {
    await this.service.unregister(req.user.sub, token);
  }

  /** Envía una notificación de prueba a los dispositivos del propio usuario. */
  @Post('notifications/test')
  test(@Req() req: { user: AuthUser }) {
    return this.service.sendToEmployee(req.user.sub, {
      title: 'MarcaYa',
      body: 'Notificación de prueba: todo está configurado.',
      data: { type: 'test' },
    });
  }

  /** RRHH: envía una notificación a un empleado. */
  @Post('notifications/send')
  @Roles('hr', 'admin')
  send(@Body() dto: SendNotificationDto) {
    return this.service.sendToEmployee(dto.employeeId, { title: dto.title, body: dto.body });
  }
}
