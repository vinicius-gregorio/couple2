import { Module } from '@nestjs/common';
import { CoupleModule } from '../couple/couple.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { DatePlansController } from './date-plans.controller';
import { DatePlansScheduler } from './date-plans.scheduler';
import { DatePlansService } from './date-plans.service';
import { DatePlanGuard } from './guards/date-plan.guard';

@Module({
  imports: [CoupleModule, NotificationsModule],
  controllers: [DatePlansController],
  providers: [DatePlansService, DatePlansScheduler, DatePlanGuard],
})
export class DatePlansModule {}
