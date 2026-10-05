import 'dotenv/config';
import { Module } from '@nestjs/common';
import { ScheduleModule } from '@nestjs/schedule';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { PrismaModule } from './prisma';
import { UsersModule } from './users';
import { AuthModule } from './auth';
import { PairingModule } from './pairing';
import { ListsModule } from './lists/lists.module';
import { CoupleModule } from './couple/couple.module';
import { NotificationsModule } from './notifications/notifications.module';
import { QuestionsModule } from './questions/questions.module';
import { MoodModule } from './mood/mood.module';
import { DatePlansModule } from './date-plans/date-plans.module';

@Module({
  imports: [
    ScheduleModule.forRoot(),
    PrismaModule,
    UsersModule,
    AuthModule,
    PairingModule,
    ListsModule,
    CoupleModule,
    NotificationsModule,
    QuestionsModule,
    MoodModule,
    DatePlansModule,
  ],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}
