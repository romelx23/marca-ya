import { Inject, Injectable, ServiceUnavailableException } from '@nestjs/common';
import { DEVICE_STORE, type DevicePlatform, type DeviceStore } from './device.store.js';
import { PUSH_TRANSPORT, type PushMessage, type PushTransport } from './push.transport.js';

@Injectable()
export class NotificationsService {
  constructor(
    @Inject(DEVICE_STORE) private readonly devices: DeviceStore,
    @Inject(PUSH_TRANSPORT) private readonly transport: PushTransport,
  ) {}

  get enabled() {
    return this.transport.enabled;
  }

  /** Guarda el token del dispositivo. Si ya existía (aunque fuera de otro empleado), lo reasigna. */
  async register(employeeId: string, token: string, platform: DevicePlatform) {
    const existing = await this.devices.findByToken(token);
    if (existing) {
      existing.employeeId = employeeId;
      existing.platform = platform;
      return this.devices.save(existing);
    }
    return this.devices.add({ employeeId, token, platform });
  }

  async unregister(employeeId: string, token: string) {
    await this.devices.removeByEmployeeAndToken(employeeId, token);
  }

  /** Envía una notificación a todos los dispositivos de un empleado y limpia los tokens muertos. */
  async sendToEmployee(employeeId: string, message: PushMessage) {
    if (!this.transport.enabled) {
      throw new ServiceUnavailableException('Notificaciones no configuradas en el servidor');
    }
    const rows = await this.devices.findByEmployee(employeeId);
    if (rows.length === 0) return { devices: 0, sent: 0, failed: 0 };

    const result = await this.transport.send(
      rows.map((r) => r.token),
      message,
    );
    await this.devices.removeTokens(result.invalidTokens);
    return { devices: rows.length, sent: result.sent, failed: result.failed };
  }
}
