import { Module } from '@nestjs/common';
import { CoupleModule } from '../couple/couple.module';
import { ActivityService } from './activity.service';
import { CLOCK, systemClock } from './clock';
import { DevicesController } from './devices.controller';
import { DevicesService } from './devices.service';
import { FeedController } from './feed.controller';
import { FeedService } from './feed.service';
import { NotificationPreferencesController } from './preferences.controller';
import { NotificationPreferencesService } from './preferences.service';
import { createPushSender } from './push-driver';
import { PUSH_SENDER } from './push-sender';
import { UpcomingRemindersService } from './upcoming-reminders.service';

@Module({
  imports: [CoupleModule],
  controllers: [
    DevicesController,
    FeedController,
    NotificationPreferencesController,
  ],
  providers: [
    DevicesService,
    FeedService,
    NotificationPreferencesService,
    ActivityService,
    UpcomingRemindersService,
    { provide: PUSH_SENDER, useFactory: () => createPushSender() },
    { provide: CLOCK, useValue: systemClock },
  ],
  exports: [ActivityService],
})
export class NotificationsModule {}
