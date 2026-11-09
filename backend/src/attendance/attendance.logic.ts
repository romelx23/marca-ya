import type { AttendanceType } from './attendance.store.js';

export interface TimedEvent {
  type: AttendanceType;
  occurredAt: Date;
}

/** Perú no usa horario de verano: UTC-5 fijo. Configurable con APP_TZ_OFFSET_MINUTES. */
export function tzOffsetMinutes(): number {
  const raw = Number(process.env.APP_TZ_OFFSET_MINUTES ?? -300);
  return Number.isFinite(raw) ? raw : -300;
}

/** Inicio (inclusive) y fin (exclusive) del día local de `date` en UTC. */
export function localDayRange(date: Date, offsetMin = tzOffsetMinutes()): { start: Date; end: Date } {
  const local = new Date(date.getTime() + offsetMin * 60_000);
  const startMs = Date.UTC(local.getUTCFullYear(), local.getUTCMonth(), local.getUTCDate()) - offsetMin * 60_000;
  return { start: new Date(startMs), end: new Date(startMs + 86_400_000) };
}

/** Convierte 'YYYY-MM-DD' (día local) a un instante dentro de ese día, o null si no es válido. */
export function parseLocalDate(value: string, offsetMin = tzOffsetMinutes()): Date | null {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(value);
  if (!m) return null;
  const [y, mo, d] = [Number(m[1]), Number(m[2]), Number(m[3])];
  const utc = new Date(Date.UTC(y, mo - 1, d));
  if (utc.getUTCFullYear() !== y || utc.getUTCMonth() !== mo - 1 || utc.getUTCDate() !== d) return null;
  return new Date(utc.getTime() - offsetMin * 60_000);
}

/** Segundos trabajados: suma cada par entrada→salida; una entrada abierta cuenta hasta `now`. */
export function workedSeconds(events: TimedEvent[], now: Date): number {
  const sorted = [...events].sort((a, b) => a.occurredAt.getTime() - b.occurredAt.getTime());
  let total = 0;
  let openSince: Date | null = null;
  for (const e of sorted) {
    if (e.type === 'in') {
      openSince ??= e.occurredAt;
    } else if (openSince) {
      total += (e.occurredAt.getTime() - openSince.getTime()) / 1000;
      openSince = null;
    }
  }
  if (openSince) total += Math.max(0, (now.getTime() - openSince.getTime()) / 1000);
  return Math.round(total);
}

/** Distancia en metros entre dos coordenadas (haversine). */
export function distanceMeters(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const rad = (d: number) => (d * Math.PI) / 180;
  const a =
    Math.sin(rad(lat2 - lat1) / 2) ** 2 +
    Math.cos(rad(lat1)) * Math.cos(rad(lat2)) * Math.sin(rad(lon2 - lon1) / 2) ** 2;
  return 2 * 6_371_000 * Math.asin(Math.sqrt(a));
}

export interface Geofence {
  latitude: number;
  longitude: number;
  radiusMeters: number;
}

/** Geocerca de la oficina desde OFFICE_LAT/OFFICE_LNG/OFFICE_RADIUS_M; null si no está configurada. */
export function officeGeofence(env = process.env): Geofence | null {
  if (!env.OFFICE_LAT || !env.OFFICE_LNG) return null;
  const latitude = Number(env.OFFICE_LAT);
  const longitude = Number(env.OFFICE_LNG);
  const radiusMeters = Number(env.OFFICE_RADIUS_M ?? 150);
  if (![latitude, longitude, radiusMeters].every(Number.isFinite)) return null;
  return { latitude, longitude, radiusMeters };
}

/** Qué marcación toca: 'in' si no hay eventos o el último fue salida; 'out' si el último fue entrada. */
export function nextType(events: TimedEvent[]): AttendanceType {
  if (events.length === 0) return 'in';
  const last = events.reduce((a, b) => (b.occurredAt.getTime() >= a.occurredAt.getTime() ? b : a));
  return last.type === 'in' ? 'out' : 'in';
}
