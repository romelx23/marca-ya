import { Column, CreateDateColumn, Entity, Index, PrimaryGeneratedColumn, UpdateDateColumn } from 'typeorm';

export type DevicePlatform = 'android' | 'ios' | 'web';

/** Token de FCM de un dispositivo de un empleado. Un empleado puede tener varios dispositivos. */
@Entity('device_tokens')
export class DeviceToken {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Index()
  @Column({ type: 'varchar' })
  employeeId!: string;

  @Index({ unique: true })
  @Column({ type: 'varchar' })
  token!: string;

  @Column({ type: 'varchar' })
  platform!: DevicePlatform;

  @CreateDateColumn()
  createdAt!: Date;

  /** Se actualiza cada vez que la app vuelve a registrar el token. */
  @UpdateDateColumn()
  lastSeenAt!: Date;
}
