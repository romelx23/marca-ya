import { Module } from '@nestjs/common';
import { FaceController } from './face.controller.js';
import { FaceMatchService } from './face-match.service.js';
import { FaceService } from './face.service.js';

/** Los puertos de persistencia vienen del PersistenceModule global. */
@Module({
  controllers: [FaceController],
  providers: [FaceService, FaceMatchService],
  exports: [FaceService, FaceMatchService],
})
export class FaceModule {}
