import {
  Controller,
  Get,
  Post,
  Patch,
  Delete,
  Body,
  Param,
  UseGuards,
} from '@nestjs/common';
import { ListsService } from './lists.service';
import { CreateListDto, AddItemDto } from './dto';
import type { Couple } from '@prisma/client';
import { JwtAuthGuard } from '../auth/guards';
import { GetUser } from '../auth/decorators';
import { GetCouple } from '../couple/decorators/get-couple.decorator';
import { CoupleGuard } from '../couple/guards/couple.guard';
import { SharedListGuard } from './guards/shared-list.guard';
import { SharedListItemGuard } from './guards/shared-list-item.guard';
import type { UserWithPartner } from '../auth/strategies/jwt.strategy';

@Controller('lists')
@UseGuards(JwtAuthGuard, CoupleGuard)
export class ListsController {
  constructor(private readonly listsService: ListsService) {}

  @Get()
  getLists(@GetCouple() couple: Couple) {
    return this.listsService.getLists(couple.id);
  }

  @Post()
  createList(
    @GetUser() user: UserWithPartner,
    @GetCouple() couple: Couple,
    @Body() dto: CreateListDto,
  ) {
    return this.listsService.createList(user.id, couple.id, dto);
  }

  @Get(':id')
  @UseGuards(SharedListGuard)
  getList(@Param('id') id: string, @GetCouple() couple: Couple) {
    return this.listsService.getList(id, couple.id);
  }

  @Post(':id/items')
  @UseGuards(SharedListGuard)
  addItem(
    @Param('id') id: string,
    @GetUser() user: UserWithPartner,
    @Body() dto: AddItemDto,
  ) {
    return this.listsService.addItem(id, user.id, dto);
  }

  @Patch('items/:id')
  @UseGuards(SharedListItemGuard)
  toggleItem(@Param('id') id: string) {
    return this.listsService.toggleItem(id);
  }

  @Delete('items/:id')
  @UseGuards(SharedListItemGuard)
  deleteItem(@Param('id') id: string) {
    return this.listsService.deleteItem(id);
  }

  @Delete(':id')
  @UseGuards(SharedListGuard)
  deleteList(@Param('id') id: string) {
    return this.listsService.deleteList(id);
  }
}
