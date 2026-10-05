import { Module } from '@nestjs/common';
import { CoupleModule } from '../couple/couple.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { IgnoreClientReceiverGuard } from './ignore-client-receiver.guard';
import { MoodController } from './mood.controller';
import { MoodService } from './mood.service';
import { NudgesController } from './nudges.controller';
import { NudgesService } from './nudges.service';

@Module({
  imports: [CoupleModule, NotificationsModule],
  controllers: [MoodController, NudgesController],
  providers: [MoodService, NudgesService, IgnoreClientReceiverGuard],
})
export class MoodModule {}
