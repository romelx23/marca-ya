import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { IsNull, Repository } from 'typeorm';
import { FaceConsent } from './face-consent.entity.js';
import { FaceTemplate } from './face-template.entity.js';
import type { FaceConsentRecord, FaceStore } from './face.store.js';

/** Adaptador de FaceStore con TypeORM (PostgreSQL o sql.js según DB_HOST). */
@Injectable()
export class TypeOrmFaceStore implements FaceStore {
  constructor(
    @InjectRepository(FaceConsent) private readonly consents: Repository<FaceConsent>,
    @InjectRepository(FaceTemplate) private readonly templates: Repository<FaceTemplate>,
  ) {}

  latestConsent(employeeId: string): Promise<FaceConsentRecord | null> {
    return this.consents.findOne({ where: { employeeId }, order: { acceptedAt: 'DESC' } });
  }

  addConsent(employeeId: string, version: string): Promise<FaceConsentRecord> {
    return this.consents.save(this.consents.create({ employeeId, version, acceptedAt: new Date(), revokedAt: null }));
  }

  async revokeConsent(employeeId: string): Promise<void> {
    await this.consents.update({ employeeId, revokedAt: IsNull() }, { revokedAt: new Date() });
  }

  templateCount(employeeId: string): Promise<number> {
    return this.templates.count({ where: { employeeId } });
  }

  async listTemplates(employeeId: string): Promise<string[]> {
    const rows = await this.templates.find({ where: { employeeId }, order: { createdAt: 'ASC' } });
    return rows.map((r) => r.embeddingEncrypted);
  }

  async replaceTemplates(employeeId: string, encryptedEmbeddings: string[]): Promise<void> {
    await this.templates.manager.transaction(async (m) => {
      const repo = m.getRepository(FaceTemplate);
      await repo.delete({ employeeId });
      await repo.insert(encryptedEmbeddings.map((embeddingEncrypted) => ({ employeeId, embeddingEncrypted })));
    });
  }

  async deleteTemplates(employeeId: string): Promise<void> {
    await this.templates.delete({ employeeId });
  }
}
