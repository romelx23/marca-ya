import { Body, Controller, Get, Inject, Post, Query, Req, UseGuards } from '@nestjs/common';
import { JwtAuthGuard, type AuthUser } from '../auth/jwt-auth.guard.js';
import { Roles } from '../auth/roles.decorator.js';
import { RolesGuard } from '../auth/roles.guard.js';
import { MarkDto, RangeQueryDto } from './attendance.dto.js';
import { AttendanceService } from './attendance.service.js';

@Controller('attendance')
@UseGuards(JwtAuthGuard, RolesGuard)
export class AttendanceController {
  constructor(@Inject(AttendanceService) private readonly service: AttendanceService) {}

  /** El empleado marca su propia entrada o salida. */
  @Post()
  mark(@Req() req: { user: AuthUser }, @Body() dto: MarkDto) {
    return this.service.mark(req.user.sub, dto);
  }

  @Get('today')
  today(@Req() req: { user: AuthUser }) {
    return this.service.today(req.user.sub);
  }

  @Get('me')
  mine(@Req() req: { user: AuthUser }, @Query() q: RangeQueryDto) {
    return this.service.range({ from: q.from, to: q.to, employeeId: req.user.sub });
  }

  /** RRHH: marcaciones de todos o de un empleado. */
  @Get()
  @Roles('hr', 'admin')
  all(@Query() q: RangeQueryDto) {
    return this.service.rangeWithNames(q);
  }
}
