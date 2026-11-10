import { Column, CreateDateColumn, Entity, Index, PrimaryGeneratedColumn } from 'typeorm';

/** Un embedding facial cifrado (AES-256-GCM). Nunca se guarda la imagen. */
@Entity('face_templates')
@Index(['employeeId'])
export class FaceTemplate {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column({ type: 'varchar' })
  employeeId!: string;

  @Column({ type: 'text' })
  embeddingEncrypted!: string;

  @CreateDateColumn()
  createdAt!: Date;
}
