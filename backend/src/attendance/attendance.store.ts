/** Puerto de persistencia de marcaciones. */

export type AttendanceType = 'in' | 'out';
export type AttendanceMethod = 'app' | 'pin' | 'qr' | 'face' | 'fingerprint' | 'manual';

export interface AttendanceRecord {
  id: string;
  employeeId: string;
  type: AttendanceType;
  occurredAt: Date;
  method: AttendanceMethod;
  deviceId: string | null;
  latitude: number | null;
  longitude: number | null;
  createdAt: Date;
}

export interface NewAttendance {
  employeeId: string;
  type: AttendanceType;
  occurredAt: Date;
  method: AttendanceMethod;
  deviceId: string | null;
  latitude: number | null;
  longitude: number | null;
}

export interface AttendanceStore {
  /** Eventos con `from <= occurredAt < to`, de un empleado o de todos, en orden cronológico. */
  find(query: { employeeId?: string; from: Date; to: Date }): Promise<AttendanceRecord[]>;
  add(event: NewAttendance): Promise<AttendanceRecord>;
}

export const ATTENDANCE_STORE = Symbol('ATTENDANCE_STORE');
