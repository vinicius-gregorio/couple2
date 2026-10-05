import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma';
import { CreateListDto, AddItemDto } from './dto';

@Injectable()
export class ListsService {
  constructor(private prisma: PrismaService) {}

  getLists(userId: string, partnerId: string | null) {
    return this.prisma.partnerList.findMany({
      where: {
        ownerId: {
          in: [userId, ...(partnerId ? [partnerId] : [])],
        },
      },
      include: { items: true },
      orderBy: { createdAt: 'desc' },
    });
  }

  createList(userId: string, dto: CreateListDto) {
    return this.prisma.partnerList.create({
      data: {
        type: dto.type,
        name: dto.name,
        ownerId: userId,
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
