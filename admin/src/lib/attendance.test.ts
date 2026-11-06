import { describe, expect, it } from 'vitest'
import { formatDuration, initials, limaDate, mapUrl, summarize, type AttendanceEvent } from './attendance'

let n = 0
const ev = (employeeId: string, type: 'in' | 'out', at: string, name = 'Ana'): AttendanceEvent => ({
  id: String(++n),
  employeeId,
  employeeName: name,
  type,
  occurredAt: at,
  method: 'app',
  deviceId: null,
})

describe('attendance helpers', () => {
  it('limaDate usa UTC-5', () => {
    expect(limaDate(new Date('2026-11-06T03:00:00Z'))).toBe('2026-11-05')
    expect(limaDate(new Date('2026-11-06T05:00:00Z'))).toBe('2026-11-06')
  })

  it('mapUrl solo existe con coordenadas', () => {
    expect(mapUrl({ latitude: null, longitude: null })).toBeNull()
    expect(mapUrl(undefined)).toBeNull()
    expect(mapUrl({ latitude: -12.04, longitude: -77.03 })).toContain('mlat=-12.04&mlon=-77.03')
  })

  it('initials', () => {
    expect(initials('Ana Ruiz')).toBe('AR')
    expect(initials('  luis  ')).toBe('L')
    expect(initials('')).toBe('?')
  })

  it('formatDuration', () => {
    expect(formatDuration(3725)).toBe('1 h 02 min')
  })

  it('suma tramos cerrados y agrupa por empleado', () => {
    const rows = summarize(
      [
        ev('1', 'in', '2026-11-06T13:00:00Z'),
        ev('1', 'out', '2026-11-06T17:00:00Z'),
        ev('1', 'in', '2026-11-06T18:00:00Z'),
        ev('1', 'out', '2026-11-06T20:00:00Z'),
        ev('2', 'in', '2026-11-06T13:30:00Z', 'Beto'),
      ],
      new Date('2026-11-06T14:30:00Z'),
    )
    expect(rows.map((r) => r.name)).toEqual(['Ana', 'Beto'])
    expect(rows[0]!.workedSeconds).toBe(6 * 3600)
    expect(rows[0]!.open).toBe(false)
    expect(rows[0]!.lastOut?.toISOString()).toBe('2026-11-06T20:00:00.000Z')
    expect(rows[1]!.open).toBe(true)
    expect(rows[1]!.workedSeconds).toBe(3600)
  })
})
