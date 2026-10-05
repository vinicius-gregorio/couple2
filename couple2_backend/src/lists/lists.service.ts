import { Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma';
import { CreateListDto, AddItemDto } from './dto';

@Injectable()
export class ListsService {
  constructor(private prisma: PrismaService) {}

  getLists(coupleId: string) {
    return this.prisma.partnerList.findMany({
      where: { coupleId },
      include: { items: true },
      orderBy: { createdAt: 'desc' },
    });
  }

  async getList(listId: string, coupleId: string) {
    const list = await this.prisma.partnerList.findFirst({
      where: { id: listId, coupleId },
      include: { items: true },
    });
    if (!list) throw new NotFoundException('List not found');
    return list;
  }

  createList(userId: string, coupleId: string, dto: CreateListDto) {
    return this.prisma.partnerList.create({
      data: {
        type: dto.type,
        name: dto.name,
        ownerId: userId,
        coupleId,
      },
      include: { items: true },
    });
  }

  addItem(listId: string, userId: string, dto: AddItemDto) {
    return this.prisma.listItem.create({
      data: {
        listId,
        content: dto.content,
        metadata: dto.metadata as Prisma.InputJsonValue,
        addedById: userId,
      },
    });
  }

  async toggleItem(itemId: string) {
    const item = await this.prisma.listItem.findUniqueOrThrow({
      where: { id: itemId },
    });
    return this.prisma.listItem.update({
      where: { id: itemId },
      data: { isCompleted: !item.isCompleted },
    });
  }

  deleteItem(itemId: string) {
    return this.prisma.listItem.delete({ where: { id: itemId } });
  }

  deleteList(listId: string) {
    return this.prisma.partnerList.delete({ where: { id: listId } });
  }
}
