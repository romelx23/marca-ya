import { Module } from '@nestjs/common';
import { NotificationsController } from './notifications.controller.js';
import { NotificationsService } from './notifications.service.js';
import { FirebaseTransport, PUSH_TRANSPORT } from './push.transport.js';

@Module({
  controllers: [NotificationsController],
  providers: [NotificationsService, { provide: PUSH_TRANSPORT, useFactory: () => new FirebaseTransport() }],
  exports: [NotificationsService],
})
export class NotificationsModule {}
