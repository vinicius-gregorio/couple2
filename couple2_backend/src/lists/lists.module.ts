import { Module } from '@nestjs/common';
import { CoupleModule } from '../couple/couple.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { PrismaModule } from '../prisma';
import { ListsController } from './lists.controller';
import { ListsService } from './lists.service';
import { SharedListGuard } from './guards/shared-list.guard';
import { SharedListItemGuard } from './guards/shared-list-item.guard';

@Module({
  imports: [PrismaModule, CoupleModule, NotificationsModule],
  controllers: [ListsController],
  providers: [ListsService, SharedListGuard, SharedListItemGuard],
})
export class ListsModule {}
