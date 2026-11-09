import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { DeviceToken } from './device-token.entity.js';
import type { DeviceRecord, DeviceStore } from './device.store.js';

/** Adaptador de DeviceStore con TypeORM (PostgreSQL o sql.js según DB_HOST). */
@Injectable()
export class TypeOrmDeviceStore implements DeviceStore {
  constructor(@InjectRepository(DeviceToken) private readonly repo: Repository<DeviceToken>) {}

  findByToken(token: string): Promise<DeviceRecord | null> {
    return this.repo.findOne({ where: { token } });
  }

  findByEmployee(employeeId: string): Promise<DeviceRecord[]> {
    return this.repo.find({ where: { employeeId } });
  }

  add(device: { employeeId: string; token: string; platform: DeviceRecord['platform'] }): Promise<DeviceRecord> {
    return this.repo.save(this.repo.create(device));
  }

  save(device: DeviceRecord): Promise<DeviceRecord> {
    return this.repo.save(device);
  }

  async removeByEmployeeAndToken(employeeId: string, token: string): Promise<void> {
    await this.repo.delete({ employeeId, token });
  }

  async removeTokens(tokens: string[]): Promise<void> {
    if (tokens.length === 0) return;
    await this.repo.delete(tokens.map((token) => ({ token })));
  }
}
