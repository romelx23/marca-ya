import { Column, CreateDateColumn, Entity, Index, PrimaryGeneratedColumn } from 'typeorm';
import type { AttendanceMethod, AttendanceType } from './attendance.store.js';

export type { AttendanceMethod, AttendanceType } from './attendance.store.js';

/** Esquema de la tabla de marcaciones para TypeORM. Solo lo usa el adaptador typeorm-attendance.store.ts. */
@Entity('attendance_events')
@Index(['employeeId', 'occurredAt'])
export class AttendanceEvent {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column({ type: 'varchar' })
  employeeId!: string;

  @Column({ type: 'varchar' })
  type!: AttendanceType;

  @Column({ type: process.env.DB_HOST ? 'timestamptz' : 'datetime' })
  occurredAt!: Date;

  @Column({ type: 'varchar', default: 'app' })
  method!: AttendanceMethod;

  /** Terminal, tablet o dispositivo IoT que originó la marcación (futuro). */
  @Column({ type: 'varchar', nullable: true })
  deviceId!: string | null;

  @Column({ type: 'float', nullable: true })
  latitude!: number | null;

  @Column({ type: 'float', nullable: true })
  longitude!: number | null;

  @CreateDateColumn()
  createdAt!: Date;
}
