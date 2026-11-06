import {
  distanceMeters,
  localDayRange,
  nextType,
  officeGeofence,
  parseLocalDate,
  workedSeconds,
  type TimedEvent,
} from './attendance.logic.js';

describe('geocerca', () => {
  it('distanceMeters: ~111 m por cada 0.001° de latitud', () => {
    expect(distanceMeters(-12.0, -77.0, -12.001, -77.0)).toBeGreaterThan(105);
    expect(distanceMeters(-12.0, -77.0, -12.001, -77.0)).toBeLessThan(117);
    expect(distanceMeters(-12, -77, -12, -77)).toBe(0);
  });

  it('officeGeofence: null sin configurar, usa 150 m por defecto', () => {
    expect(officeGeofence({})).toBeNull();
    expect(officeGeofence({ OFFICE_LAT: 'x', OFFICE_LNG: '1' })).toBeNull();
    expect(officeGeofence({ OFFICE_LAT: '-12.04', OFFICE_LNG: '-77.03' })).toEqual({
      latitude: -12.04,
      longitude: -77.03,
      radiusMeters: 150,
    });
  });
});

const at = (iso: string) => new Date(iso);
const ev = (type: 'in' | 'out', iso: string): TimedEvent => ({ type, occurredAt: at(iso) });

describe('localDayRange (Lima, UTC-5)', () => {
  it('el día local empieza a las 05:00 UTC', () => {
    const { start, end } = localDayRange(at('2026-11-05T20:00:00Z'), -300);
    expect(start.toISOString()).toBe('2026-11-05T05:00:00.000Z');
    expect(end.toISOString()).toBe('2026-11-06T05:00:00.000Z');
  });

  it('02:00 UTC todavía es el día anterior en Lima', () => {
    const { start } = localDayRange(at('2026-11-06T02:00:00Z'), -300);
    expect(start.toISOString()).toBe('2026-11-05T05:00:00.000Z');
  });
});

describe('parseLocalDate', () => {
  it('acepta fechas válidas y rechaza inválidas', () => {
    expect(parseLocalDate('2026-11-05', -300)?.toISOString()).toBe('2026-11-05T05:00:00.000Z');
    expect(parseLocalDate('2026-02-30', -300)).toBeNull();
    expect(parseLocalDate('05/11/2026', -300)).toBeNull();
  });
});

describe('workedSeconds', () => {
  const now = at('2026-11-05T20:00:00Z');

  it('suma varios pares entrada/salida', () => {
    const events = [
      ev('in', '2026-11-05T13:00:00Z'),
      ev('out', '2026-11-05T17:00:00Z'),
      ev('in', '2026-11-05T18:00:00Z'),
      ev('out', '2026-11-05T19:00:00Z'),
    ];
    expect(workedSeconds(events, now)).toBe(5 * 3600);
  });

  it('una entrada abierta cuenta hasta ahora', () => {
    expect(workedSeconds([ev('in', '2026-11-05T18:30:00Z')], now)).toBe(90 * 60);
  });

  it('ignora una salida sin entrada y no depende del orden de entrada', () => {
    const events = [ev('out', '2026-11-05T12:00:00Z'), ev('out', '2026-11-05T17:00:00Z'), ev('in', '2026-11-05T16:00:00Z')];
    expect(workedSeconds(events, now)).toBe(3600);
  });

  it('sin eventos es cero', () => {
    expect(workedSeconds([], now)).toBe(0);
  });
});

describe('nextType', () => {
  it('alterna entrada y salida', () => {
    expect(nextType([])).toBe('in');
    expect(nextType([ev('in', '2026-11-05T13:00:00Z')])).toBe('out');
    expect(nextType([ev('in', '2026-11-05T13:00:00Z'), ev('out', '2026-11-05T14:00:00Z')])).toBe('in');
  });
});
