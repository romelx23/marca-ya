import { Column, Entity, Index, PrimaryGeneratedColumn } from 'typeorm';

/** Consentimiento expreso para reconocimiento facial. Cada aceptación es un registro nuevo. */
@Entity('face_consents')
@Index(['employeeId', 'acceptedAt'])
export class FaceConsent {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column({ type: 'varchar' })
  employeeId!: string;

  @Column({ type: 'varchar' })
  version!: string;

  @Column({ type: process.env.DB_HOST ? 'timestamptz' : 'datetime' })
  acceptedAt!: Date;

  @Column({ type: process.env.DB_HOST ? 'timestamptz' : 'datetime', nullable: true })
  revokedAt!: Date | null;
}
