import { Module } from '@nestjs/common';
import { PrismaModule } from '../prisma';
import { ListsController } from './lists.controller';
import { ListsService } from './lists.service';
import { SharedListGuard } from './guards/shared-list.guard';

@Module({
  imports: [PrismaModule],
  controllers: [ListsController],
  providers: [ListsService, SharedListGuard],
})
export class ListsModule {}
