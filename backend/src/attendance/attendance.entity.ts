import { Column, CreateDateColumn, Entity, Index, PrimaryGeneratedColumn } from 'typeorm';

export type AttendanceType = 'in' | 'out';
export type AttendanceMethod = 'app' | 'pin' | 'qr' | 'face' | 'fingerprint' | 'manual';

/** Registro inmutable de una marcación. La hora siempre la pone el servidor. */
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
