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
import { JwtAuthGuard, PairingGuard } from '../auth/guards';
import { GetUser } from '../auth/decorators';
import { SharedListGuard } from './guards/shared-list.guard';
import type { UserWithPartner } from '../auth/strategies/jwt.strategy';

@Controller('lists')
@UseGuards(JwtAuthGuard, PairingGuard)
export class ListsController {
  constructor(private readonly listsService: ListsService) {}

  @Get()
  getLists(@GetUser() user: UserWithPartner) {
    return this.listsService.getLists(user.id, user.partnerId);
  }

  @Post()
  createList(@GetUser() user: UserWithPartner, @Body() dto: CreateListDto) {
    return this.listsService.createList(user.id, dto);
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
  toggleItem(@Param('id') id: string) {
    return this.listsService.toggleItem(id);
  }

  @Delete('items/:id')
  deleteItem(@Param('id') id: string) {
    return this.listsService.deleteItem(id);
  }

  @Delete(':id')
  @UseGuards(SharedListGuard)
  deleteList(@Param('id') id: string) {
    return this.listsService.deleteList(id);
  }
}
