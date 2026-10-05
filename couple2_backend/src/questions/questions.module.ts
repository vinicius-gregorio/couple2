import { Module } from '@nestjs/common';
import { CoupleModule } from '../couple/couple.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { DailyQuestionScheduler } from './daily-question.scheduler';
import { QuestionsController } from './questions.controller';
import { QuestionsService } from './questions.service';

@Module({
  imports: [CoupleModule, NotificationsModule],
  controllers: [QuestionsController],
  providers: [QuestionsService, DailyQuestionScheduler],
  exports: [QuestionsService],
})
export class QuestionsModule {}
