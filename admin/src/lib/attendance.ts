export interface AttendanceEvent {
  id: string
  employeeId: string
  employeeName: string | null
  type: 'in' | 'out'
  occurredAt: string
  method: string
  deviceId: string | null
  latitude?: number | null
  longitude?: number | null
}

/** Enlace a OpenStreetMap con la ubicación de la marcación, o null si no tiene. */
export function mapUrl(e: Pick<AttendanceEvent, 'latitude' | 'longitude'> | undefined): string | null {
  if (e?.latitude == null || e.longitude == null) return null
  return `https://www.openstreetmap.org/?mlat=${e.latitude}&mlon=${e.longitude}#map=18/${e.latitude}/${e.longitude}`
}

export interface DaySummary {
  employeeId: string
  name: string
  firstIn: Date | null
  lastOut: Date | null
  workedSeconds: number
  open: boolean
  firstInEvent: AttendanceEvent | undefined
  events: AttendanceEvent[]
}

/** Iniciales para el avatar: "Ana Ruiz" → "AR". */
export function initials(name: string): string {
  const parts = name.trim().split(/\s+/).filter(Boolean)
  return (parts.slice(0, 2).map((p) => p[0]).join('') || '?').toUpperCase()
}

const LIMA_TZ = 'America/Lima'

/** Fecha AAAA-MM-DD en Lima (UTC-5, sin horario de verano). */
export function limaDate(now = new Date()): string {
  return new Date(now.getTime() - 5 * 3600_000).toISOString().slice(0, 10)
}

export function formatTime(d: Date): string {
  return d.toLocaleTimeString('es-PE', { hour: '2-digit', minute: '2-digit', hour12: false, timeZone: LIMA_TZ })
}

export function formatDuration(seconds: number): string {
  const h = Math.floor(seconds / 3600)
  const m = Math.floor((seconds % 3600) / 60)
  return `${h} h ${String(m).padStart(2, '0')} min`
}

/** Agrupa los eventos por empleado; una entrada abierta cuenta hasta `now`. */
export function summarize(events: AttendanceEvent[], now = new Date()): DaySummary[] {
  const byEmployee = new Map<string, AttendanceEvent[]>()
  for (const e of events) {
    const list = byEmployee.get(e.employeeId) ?? []
    list.push(e)
    byEmployee.set(e.employeeId, list)
  }

  const rows: DaySummary[] = []
  for (const [employeeId, list] of byEmployee) {
    list.sort((a, b) => a.occurredAt.localeCompare(b.occurredAt))
    let worked = 0
    let openSince: Date | null = null
    let firstIn: Date | null = null
    let lastOut: Date | null = null
    for (const e of list) {
      const at = new Date(e.occurredAt)
      if (e.type === 'in' && !openSince) {
        openSince = at
        firstIn ??= at
      } else if (e.type === 'out' && openSince) {
        worked += (at.getTime() - openSince.getTime()) / 1000
        openSince = null
        lastOut = at
      }
    }
    const open = openSince !== null
    if (openSince) worked += Math.max(0, (now.getTime() - openSince.getTime()) / 1000)
    rows.push({
      employeeId,
      name: list[0]!.employeeName ?? 'Desconocido',
      firstIn,
      lastOut,
      workedSeconds: Math.floor(worked),
      open,
      firstInEvent: list.find((e) => e.type === 'in'),
      events: list,
    })
  }
  return rows.sort((a, b) => a.name.localeCompare(b.name))
}
