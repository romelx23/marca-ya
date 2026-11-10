import { Body, Controller, Delete, Get, Inject, Post, Req, UseGuards } from '@nestjs/common';
import { JwtAuthGuard, type AuthUser } from '../auth/jwt-auth.guard.js';
import { RolesGuard } from '../auth/roles.guard.js';
import { ConsentDto, EnrollDto } from './face.dto.js';
import { FaceService } from './face.service.js';

/** Todas las rutas son del propio empleado: nadie gestiona el rostro de otro. */
@Controller('face')
@UseGuards(JwtAuthGuard, RolesGuard)
export class FaceController {
  constructor(@Inject(FaceService) private readonly service: FaceService) {}

  @Get('status')
  status(@Req() req: { user: AuthUser }) {
    return this.service.status(req.user.sub);
  }

  @Post('consent')
  consent(@Req() req: { user: AuthUser }, @Body() dto: ConsentDto) {
    return this.service.giveConsent(req.user.sub, dto.version);
  }

  @Post('enroll')
  enroll(@Req() req: { user: AuthUser }, @Body() dto: EnrollDto) {
    return this.service.enroll(req.user.sub, dto.embeddings, dto.pin);
  }

  @Delete('enroll')
  revoke(@Req() req: { user: AuthUser }) {
    return this.service.revoke(req.user.sub);
  }
}
