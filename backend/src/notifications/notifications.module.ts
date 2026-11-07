import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { DeviceToken } from './device-token.entity.js';
import { NotificationsController } from './notifications.controller.js';
import { NotificationsService } from './notifications.service.js';
import { FirebaseTransport, PUSH_TRANSPORT } from './push.transport.js';

@Module({
  imports: [TypeOrmModule.forFeature([DeviceToken])],
  controllers: [NotificationsController],
  providers: [NotificationsService, { provide: PUSH_TRANSPORT, useFactory: () => new FirebaseTransport() }],
  exports: [NotificationsService],
})
export class NotificationsModule {}
