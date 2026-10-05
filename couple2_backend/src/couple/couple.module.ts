import { Module } from '@nestjs/common';
import { CoupleController } from './couple.controller';
import { CoupleService } from './couple.service';
import { CoupleGuard } from './guards/couple.guard';

@Module({
  controllers: [CoupleController],
  providers: [CoupleService, CoupleGuard],
  exports: [CoupleGuard],
})
export class CoupleModule {}
