import { BadRequestException, ConflictException, ForbiddenException, Inject, Injectable } from '@nestjs/common';
import { EmployeesService } from '../employees/employees.service.js';
import { FaceMatchService } from '../face/face-match.service.js';
import { distanceMeters, localDayRange, nextType, officeGeofence, parseLocalDate, workedSeconds } from './attendance.logic.js';
import { ATTENDANCE_STORE, type AttendanceMethod, type AttendanceStore } from './attendance.store.js';
import type { MarkDto } from './attendance.dto.js';

const MAX_RANGE_DAYS = 62;

@Injectable()
export class AttendanceService {
  /** Serializa las marcaciones de un mismo empleado para que dos taps seguidos no dupliquen. */
  private readonly locks = new Map<string, Promise<unknown>>();

  constructor(
    @Inject(ATTENDANCE_STORE) private readonly store: AttendanceStore,
    @Inject(EmployeesService) private readonly employees: EmployeesService,
    @Inject(FaceMatchService) private readonly faceMatch: FaceMatchService,
  ) {}

  private async withLock<T>(key: string, fn: () => Promise<T>): Promise<T> {
    const prev = this.locks.get(key) ?? Promise.resolve();
    const next = prev.catch(() => undefined).then(fn);
    this.locks.set(key, next);
    try {
      return await next;
    } finally {
      if (this.locks.get(key) === next) this.locks.delete(key);
    }
  }

  private eventsOfDay(employeeId: string, now: Date) {
    const { start, end } = localDayRange(now);
    return this.store.find({ employeeId, from: start, to: end });
  }

  async mark(
    employeeId: string,
    dto: MarkDto,
    opts: { method?: AttendanceMethod; deviceId?: string; now?: Date } = {},
  ) {
    if ((dto.latitude === undefined) !== (dto.longitude === undefined)) {
      throw new BadRequestException('Envía latitud y longitud juntas');
    }
    if (dto.embedding !== undefined && dto.pin !== undefined) {
      throw new BadRequestException('Envía rostro o PIN, no ambos');
    }
    // El método lo decide lo que llega: embedding → face, PIN → pin, nada → app (desde el teléfono).
    const method: AttendanceMethod = opts.method ?? (dto.embedding ? 'face' : dto.pin ? 'pin' : 'app');
    const fence = ['app', 'face', 'pin'].includes(method) ? officeGeofence() : null;
    if (fence) {
      if (dto.latitude === undefined || dto.longitude === undefined) {
        throw new ForbiddenException('Activa tu ubicación para marcar');
      }
      const d = distanceMeters(dto.latitude, dto.longitude, fence.latitude, fence.longitude);
      if (d > fence.radiusMeters) {
        throw new ForbiddenException(`Estás a ${Math.round(d)} m de la oficina; acércate para marcar`);
      }
    }
    if (method === 'face') {
      const r = await this.faceMatch.verify(employeeId, dto.embedding!);
      if (r.score === null) throw new ForbiddenException('No tienes rostro registrado: regístralo o usa tu PIN');
      if (!r.matched) throw new ForbiddenException('Rostro no reconocido: intenta de nuevo o usa tu PIN');
    }
    if (method === 'pin' && !(await this.employees.verifyPin(employeeId, dto.pin!))) {
      throw new ForbiddenException('PIN incorrecto');
    }
    return this.withLock(employeeId, async () => {
      const now = opts.now ?? new Date();
      const today = await this.eventsOfDay(employeeId, now);
      const expected = nextType(today);
      if (dto.type !== expected) {
        throw new ConflictException(
          expected === 'in' ? 'No tienes una entrada abierta: marca entrada primero' : 'Ya marcaste entrada: marca salida',
        );
      }
      return this.store.add({
        employeeId,
        type: dto.type,
        occurredAt: now,
        method,
        deviceId: opts.deviceId ?? null,
        latitude: dto.latitude ?? null,
        longitude: dto.longitude ?? null,
      });
    });
  }

  async today(employeeId: string, now = new Date()) {
    const events = await this.eventsOfDay(employeeId, now);
    const nextAction = nextType(events);
    return {
      events,
      checkedIn: nextAction === 'out',
      nextAction,
      workedSeconds: workedSeconds(events, now),
    };
  }

  /** Eventos en el rango de días locales [from, to], ambos inclusive. */
  async range(opts: { from?: string; to?: string; employeeId?: string }, now = new Date()) {
    const fromDate = opts.from ? parseLocalDate(opts.from) : localDayRange(now).start;
    const toDate = opts.to ? parseLocalDate(opts.to) : fromDate;
    if (!fromDate || !toDate) throw new BadRequestException('Fechas inválidas: usa AAAA-MM-DD');
    const start = localDayRange(fromDate).start;
    const end = localDayRange(toDate).end;
    if (end <= start) throw new BadRequestException('"to" debe ser igual o posterior a "from"');
    if ((end.getTime() - start.getTime()) / 86_400_000 > MAX_RANGE_DAYS) {
      throw new BadRequestException(`El rango máximo es de ${MAX_RANGE_DAYS} días`);
    }
    return this.store.find({ employeeId: opts.employeeId, from: start, to: end });
  }

  /** Para RRHH: eventos con el nombre del empleado. */
  async rangeWithNames(opts: { from?: string; to?: string; employeeId?: string }) {
    const [events, people] = await Promise.all([this.range(opts), this.employees.findAll()]);
    const names = new Map(people.map((p) => [p.id, p.fullName]));
    return events.map((e) => ({ ...e, employeeName: names.get(e.employeeId) ?? null }));
  }
}
