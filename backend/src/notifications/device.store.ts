/** Puerto de persistencia de tokens de dispositivo (FCM). */

export type DevicePlatform = 'android' | 'ios' | 'web';

export interface DeviceRecord {
  id: string;
  employeeId: string;
  token: string;
  platform: DevicePlatform;
  createdAt: Date;
  lastSeenAt: Date;
}

export interface DeviceStore {
  findByToken(token: string): Promise<DeviceRecord | null>;
  findByEmployee(employeeId: string): Promise<DeviceRecord[]>;
  add(device: { employeeId: string; token: string; platform: DevicePlatform }): Promise<DeviceRecord>;
  save(device: DeviceRecord): Promise<DeviceRecord>;
  removeByEmployeeAndToken(employeeId: string, token: string): Promise<void>;
  removeTokens(tokens: string[]): Promise<void>;
}

export const DEVICE_STORE = Symbol('DEVICE_STORE');
