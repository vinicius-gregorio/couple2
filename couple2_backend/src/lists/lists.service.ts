import {
  BadRequestException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { ActivityType, ListType, ListVisibility, Prisma } from '@prisma/client';
import { PrismaService } from '../prisma';
import { ActivityService } from '../notifications/activity.service';
import type { RecordActivityInput } from '../notifications/activity.service';
import { CreateListDto, AddItemDto } from './dto';
import { validateGiftItemMetadata } from './gift-metadata';
import { listEmitsActivity } from './list-activity';
import { listAccessWhere } from './list-access';

type ListReader = { id: string; coupleId: string | null };

@Injectable()
export class ListsService {
  private readonly logger = new Logger(ListsService.name);

  constructor(
    private prisma: PrismaService,
    private readonly activity: ActivityService,
  ) {}

  getLists(user: ListReader) {
    return this.prisma.partnerList.findMany({
      where: listAccessWhere(user),
      include: { items: true },
      orderBy: { createdAt: 'desc' },
    });
  }

  async getList(listId: string, user: ListReader) {
    const list = await this.prisma.partnerList.findFirst({
      where: { id: listId, AND: [listAccessWhere(user)] },
      include: { items: true },
    });
    if (!list) throw new NotFoundException('List not found');
    return list;
  }

  async createList(userId: string, coupleId: string, dto: CreateListDto) {
    const visibility = this.resolveVisibility(dto);
    const list = await this.prisma.partnerList.create({
      data: {
        type: dto.type,
        name: dto.name,
        ownerId: userId,
        coupleId,
        visibility,
      },
      include: { items: true },
    });

    if (listEmitsActivity(list)) {
      await this.safeRecord({
        coupleId,
        actorId: userId,
        type: ActivityType.LIST_CREATED,
        entity: { type: 'PartnerList', id: list.id },
        payload: { listId: list.id, listName: list.name },
        push: { route: `/lists/${list.id}`, listId: list.id },
      });
    }

    return list;
  }

  async addItem(listId: string, userId: string, dto: AddItemDto) {
    const list = await this.prisma.partnerList.findUnique({
      where: { id: listId },
    });
    if (!list) throw new NotFoundException('List not found');

    const metadata = this.itemMetadata(list.type, dto.metadata);
    const item = await this.prisma.listItem.create({
      data: {
        listId,
        content: dto.content,
        metadata,
        addedById: userId,
      },
    });

    if (list.coupleId && listEmitsActivity(list)) {
      await this.safeRecord({
        coupleId: list.coupleId,
        actorId: userId,
        type: ActivityType.LIST_ITEM_ADDED,
        entity: { type: 'ListItem', id: item.id },
        payload: {
          listId: list.id,
          listName: list.name,
          content: item.content,
        },
        push: { route: `/lists/${list.id}`, listId: list.id },
      });
    }

    return item;
  }

  async toggleItem(itemId: string, actorId: string) {
    const item = await this.prisma.listItem.findUniqueOrThrow({
      where: { id: itemId },
      include: { list: true },
    });
    const updated = await this.prisma.listItem.update({
      where: { id: itemId },
      data: { isCompleted: !item.isCompleted },
    });

    const becameComplete = !item.isCompleted && updated.isCompleted;
    if (becameComplete && item.list.coupleId && listEmitsActivity(item.list)) {
      await this.safeRecord({
        coupleId: item.list.coupleId,
        actorId,
        type: ActivityType.LIST_ITEM_COMPLETED,
        entity: { type: 'ListItem', id: item.id },
        payload: {
          listId: item.list.id,
          listName: item.list.name,
          content: item.content,
        },
        push: { route: `/lists/${item.list.id}`, listId: item.list.id },
      });
    }

    return updated;
  }

  deleteItem(itemId: string) {
    return this.prisma.listItem.delete({ where: { id: itemId } });
  }

  deleteList(listId: string) {
    return this.prisma.partnerList.delete({ where: { id: listId } });
  }

  private resolveVisibility(dto: CreateListDto): ListVisibility {
    const visibility =
      dto.visibility ??
      (dto.type === ListType.GIFT_IDEAS
        ? ListVisibility.PRIVATE_FROM_PARTNER
        : ListVisibility.SHARED);

    if (
      visibility === ListVisibility.PRIVATE_FROM_PARTNER &&
      dto.type !== ListType.GIFT_IDEAS
    ) {
      throw new BadRequestException(
        'PRIVATE_FROM_PARTNER is only allowed for GIFT_IDEAS',
      );
    }

    return visibility;
  }

  private itemMetadata(
    type: ListType,
    metadata: Record<string, unknown> | undefined,
  ): Prisma.InputJsonValue | undefined {
    if (type === ListType.GIFT_IDEAS) {
      return validateGiftItemMetadata(metadata);
    }
    return metadata as Prisma.InputJsonValue | undefined;
  }

  /**
   * The list write has already committed. A feed/push failure must not turn
   * that success into a 500.
   */
  private async safeRecord(input: RecordActivityInput): Promise<void> {
    try {
      await this.activity.record(input);
    } catch (error) {
      this.logger.error(
        'Activity record failed after the list write committed',
        error instanceof Error ? error.stack : String(error),
      );
    }
  }
}
