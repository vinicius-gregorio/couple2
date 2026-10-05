import {
  ConflictException,
  ForbiddenException,
  Injectable,
  Logger,
  NotFoundException,
  UnprocessableEntityException,
} from '@nestjs/common';
import {
  ActivityType,
  DatePlan,
  DatePlanStatus,
  ListType,
  Prisma,
} from '@prisma/client';
import { ActivityService } from '../notifications/activity.service';
import type { RecordActivityInput } from '../notifications/activity.service';
import { PrismaService } from '../prisma';
import { decodeDatePlanCursor, encodeDatePlanCursor } from './date-plan-cursor';
import {
  DATE_PLAN_LIST_TYPES,
  DATE_PLAN_PAGE_DEFAULT,
  DatePlanScope,
  buildDatePlanListWhere,
  canMarkDone,
  datePlanOrder,
  doneDeadline,
} from './date-plan-policy';
import { formatDatePlanWhen, parseFutureScheduledAt } from './date-plan-time';
import type { CounterDatePlanDto } from './dto/counter-date-plan.dto';
import type { CreateDatePlanDto } from './dto/create-date-plan.dto';
import type { DatePlanNoteDto } from './dto/date-plan-note.dto';
import type { ListDatePlansQueryDto } from './dto/list-date-plans-query.dto';
import type { UpdateDatePlanDto } from './dto/update-date-plan.dto';

export interface DatePlanActor {
  id: string;
}

export interface DatePlanCouple {
  id: string;
  timezone: string;
}

export interface DatePlanSourceItem {
  id: string;
  content: string;
  isCompleted: boolean;
  listType: ListType;
  listId: string;
}

export interface DatePlanView {
  id: string;
  coupleId: string;
  proposerId: string;
  title: string;
  description: string | null;
  location: string | null;
  scheduledAt: Date;
  status: DatePlanStatus;
  responseNote: string | null;
  respondedAt: Date | null;
  completedAt: Date | null;
  reminderSentAt: Date | null;
  sourceListItemId: string | null;
  sourceListItem: DatePlanSourceItem | null;
  createdById: string;
  createdAt: Date;
  updatedAt: Date;
}

const SOURCE_LIST_MESSAGE =
  'sourceListItemId must belong to a MOVIES or TRAVEL list in this couple';

const STALE_MESSAGE = 'Date plan was updated. Try again.';

@Injectable()
export class DatePlansService {
  private readonly logger = new Logger(DatePlansService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly activity: ActivityService,
  ) {}

  async create(
    user: DatePlanActor,
    couple: DatePlanCouple,
    dto: CreateDatePlanDto,
    now = new Date(),
  ): Promise<DatePlanView> {
    const scheduledAt = parseFutureScheduledAt(dto.scheduledAt, now);
    if (dto.sourceListItemId) {
      await this.assertSource(couple.id, dto.sourceListItemId);
    }

    const plan = await this.prisma.datePlan.create({
      data: {
        coupleId: couple.id,
        proposerId: user.id,
        title: dto.title,
        description: dto.description ?? null,
        location: dto.location ?? null,
        scheduledAt,
        status: DatePlanStatus.PROPOSED,
        sourceListItemId: dto.sourceListItemId ?? null,
        createdById: user.id,
      },
    });

    await this.emit(user.id, couple, plan, ActivityType.DATE_PLAN_PROPOSED);
    return this.present(plan);
  }

  async list(
    couple: DatePlanCouple,
    query: ListDatePlansQueryDto,
    now = new Date(),
  ): Promise<{ items: DatePlanView[]; nextCursor: string | null }> {
    const scope: DatePlanScope = query.scope;
    const limit = query.limit ?? DATE_PLAN_PAGE_DEFAULT;
    const cursor = query.cursor ? decodeDatePlanCursor(query.cursor) : null;
    const rows = await this.prisma.datePlan.findMany({
      where: buildDatePlanListWhere(couple.id, scope, now, cursor),
      orderBy: datePlanOrder(scope),
      take: limit + 1,
    });
    const page = rows.slice(0, limit);
    const nextCursor =
      rows.length > limit ? encodeDatePlanCursor(page[page.length - 1]) : null;
    return { items: await this.presentMany(page), nextCursor };
  }

  async get(coupleId: string, id: string): Promise<DatePlanView> {
    return this.present(await this.require(coupleId, id));
  }

  async update(
    user: DatePlanActor,
    couple: DatePlanCouple,
    id: string,
    dto: UpdateDatePlanDto,
    now = new Date(),
  ): Promise<DatePlanView> {
    const plan = await this.require(couple.id, id);
    if (plan.proposerId !== user.id) {
      throw new ForbiddenException('Only the proposer can edit this date');
    }

    const data: Prisma.DatePlanUpdateManyMutationInput = {};
    if (dto.title !== undefined) data.title = dto.title;
    if (dto.description !== undefined) data.description = dto.description;
    if (dto.location !== undefined) data.location = dto.location;
    if (dto.scheduledAt !== undefined) {
      data.scheduledAt = parseFutureScheduledAt(dto.scheduledAt, now);
    }
    if (dto.sourceListItemId !== undefined) {
      if (dto.sourceListItemId) {
        await this.assertSource(couple.id, dto.sourceListItemId);
      }
      data.sourceListItemId = dto.sourceListItemId;
    }

    if (Object.keys(data).length === 0) {
      if (plan.status !== DatePlanStatus.PROPOSED) {
        throw new ConflictException(STALE_MESSAGE);
      }
      return this.present(plan);
    }

    const updated = await this.transition({
      id,
      coupleId: couple.id,
      where: {
        status: DatePlanStatus.PROPOSED,
        proposerId: user.id,
      },
      data,
    });
    return this.present(updated);
  }

  async accept(
    user: DatePlanActor,
    couple: DatePlanCouple,
    id: string,
    now = new Date(),
  ): Promise<DatePlanView> {
    const plan = await this.require(couple.id, id);
    if (plan.proposerId === user.id) {
      throw new ForbiddenException('Only your partner can accept this date');
    }
    const updated = await this.transition({
      id,
      coupleId: couple.id,
      where: {
        status: DatePlanStatus.PROPOSED,
        proposerId: { not: user.id },
      },
      data: { status: DatePlanStatus.ACCEPTED, respondedAt: now },
    });
    await this.emit(user.id, couple, updated, ActivityType.DATE_PLAN_ACCEPTED);
    return this.present(updated);
  }

  async decline(
    user: DatePlanActor,
    couple: DatePlanCouple,
    id: string,
    dto: DatePlanNoteDto,
    now = new Date(),
  ): Promise<DatePlanView> {
    const plan = await this.require(couple.id, id);
    if (plan.proposerId === user.id) {
      throw new ForbiddenException('Only your partner can decline this date');
    }
    const updated = await this.transition({
      id,
      coupleId: couple.id,
      where: {
        status: DatePlanStatus.PROPOSED,
        proposerId: { not: user.id },
      },
      data: {
        status: DatePlanStatus.DECLINED,
        responseNote: dto.note ?? null,
        respondedAt: now,
      },
    });
    await this.emit(user.id, couple, updated, ActivityType.DATE_PLAN_DECLINED);
    return this.present(updated);
  }

  async counter(
    user: DatePlanActor,
    couple: DatePlanCouple,
    id: string,
    dto: CounterDatePlanDto,
    now = new Date(),
  ): Promise<DatePlanView> {
    const plan = await this.require(couple.id, id);
    if (plan.proposerId === user.id) {
      throw new ForbiddenException('Only your partner can suggest a new time');
    }
    const scheduledAt = parseFutureScheduledAt(dto.scheduledAt, now);
    const updated = await this.transition({
      id,
      coupleId: couple.id,
      where: {
        status: DatePlanStatus.PROPOSED,
        proposerId: { not: user.id },
      },
      data: {
        status: DatePlanStatus.PROPOSED,
        proposerId: user.id,
        scheduledAt,
        responseNote: dto.note ?? null,
        respondedAt: now,
      },
    });
    await this.emit(user.id, couple, updated, ActivityType.DATE_PLAN_COUNTERED);
    return this.present(updated);
  }

  async cancel(
    user: DatePlanActor,
    couple: DatePlanCouple,
    id: string,
    dto: DatePlanNoteDto,
    now = new Date(),
  ): Promise<DatePlanView> {
    const plan = await this.require(couple.id, id);
    let where: Prisma.DatePlanWhereInput;
    if (plan.status === DatePlanStatus.PROPOSED) {
      if (plan.proposerId !== user.id) {
        throw new ForbiddenException('Only the proposer can cancel this date');
      }
      where = {
        status: DatePlanStatus.PROPOSED,
        proposerId: user.id,
      };
    } else if (plan.status === DatePlanStatus.ACCEPTED) {
      where = { status: DatePlanStatus.ACCEPTED };
    } else {
      throw new ConflictException(STALE_MESSAGE);
    }

    const updated = await this.transition({
      id,
      coupleId: couple.id,
      where,
      data: {
        status: DatePlanStatus.CANCELLED,
        responseNote: dto.note ?? null,
        respondedAt: now,
      },
    });
    await this.emit(user.id, couple, updated, ActivityType.DATE_PLAN_CANCELLED);
    return this.present(updated);
  }

  async done(
    user: DatePlanActor,
    couple: DatePlanCouple,
    id: string,
    now = new Date(),
  ): Promise<DatePlanView> {
    const plan = await this.require(couple.id, id);
    if (plan.status !== DatePlanStatus.ACCEPTED) {
      throw new ConflictException(STALE_MESSAGE);
    }
    if (!canMarkDone(plan.scheduledAt, now)) {
      throw new UnprocessableEntityException(
        'A date can be marked done only within 2 hours of its start',
      );
    }
    const updated = await this.transition({
      id,
      coupleId: couple.id,
      where: {
        status: DatePlanStatus.ACCEPTED,
        scheduledAt: { lte: doneDeadline(now) },
      },
      data: { status: DatePlanStatus.DONE, completedAt: now },
    });
    await this.emit(user.id, couple, updated, ActivityType.DATE_PLAN_DONE);
    return this.present(updated);
  }

  private async transition(input: {
    id: string;
    coupleId: string;
    where: Prisma.DatePlanWhereInput;
    data: Prisma.DatePlanUpdateManyMutationInput;
  }): Promise<DatePlan> {
    const result = await this.prisma.datePlan.updateMany({
      where: { id: input.id, coupleId: input.coupleId, ...input.where },
      data: input.data,
    });
    if (result.count === 0) {
      throw new ConflictException(STALE_MESSAGE);
    }
    return this.require(input.coupleId, input.id);
  }

  private async require(coupleId: string, id: string): Promise<DatePlan> {
    const plan = await this.prisma.datePlan.findFirst({
      where: { id, coupleId },
    });
    if (!plan) throw new NotFoundException('Date plan not found');
    return plan;
  }

  private async assertSource(
    coupleId: string,
    sourceListItemId: string,
  ): Promise<void> {
    const item = await this.prisma.listItem.findUnique({
      where: { id: sourceListItemId },
      include: {
        list: { select: { coupleId: true, type: true } },
      },
    });
    if (
      !item ||
      item.list.coupleId !== coupleId ||
      !DATE_PLAN_LIST_TYPES.includes(item.list.type)
    ) {
      throw new UnprocessableEntityException(SOURCE_LIST_MESSAGE);
    }
  }

  private async present(plan: DatePlan): Promise<DatePlanView> {
    const [view] = await this.presentMany([plan]);
    return view;
  }

  private async presentMany(plans: DatePlan[]): Promise<DatePlanView[]> {
    const ids = [
      ...new Set(
        plans
          .map((plan) => plan.sourceListItemId)
          .filter((id): id is string => !!id),
      ),
    ];
    const items =
      ids.length === 0
        ? []
        : await this.prisma.listItem.findMany({
            where: { id: { in: ids } },
            include: {
              list: { select: { id: true, coupleId: true, type: true } },
            },
          });
    const byId = new Map(items.map((item) => [item.id, item]));
    return plans.map((plan) => {
      const item = plan.sourceListItemId
        ? byId.get(plan.sourceListItemId)
        : undefined;
      const sourceListItem =
        item && item.list.coupleId === plan.coupleId
          ? {
              id: item.id,
              content: item.content,
              isCompleted: item.isCompleted,
              listType: item.list.type,
              listId: item.list.id,
            }
          : null;
      return {
        id: plan.id,
        coupleId: plan.coupleId,
        proposerId: plan.proposerId,
        title: plan.title,
        description: plan.description,
        location: plan.location,
        scheduledAt: plan.scheduledAt,
        status: plan.status,
        responseNote: plan.responseNote,
        respondedAt: plan.respondedAt,
        completedAt: plan.completedAt,
        reminderSentAt: plan.reminderSentAt,
        sourceListItemId: plan.sourceListItemId,
        sourceListItem,
        createdById: plan.createdById,
        createdAt: plan.createdAt,
        updatedAt: plan.updatedAt,
      };
    });
  }

  private async emit(
    actorId: string,
    couple: DatePlanCouple,
    plan: DatePlan,
    type: ActivityType,
  ): Promise<void> {
    await this.safeRecord({
      coupleId: couple.id,
      actorId,
      type,
      entity: { type: 'DatePlan', id: plan.id },
      payload: {
        title: plan.title,
        scheduledAt: plan.scheduledAt.toISOString(),
        whenLabel: formatDatePlanWhen(plan.scheduledAt, couple.timezone),
        location: plan.location,
        status: plan.status,
        responseNote: plan.responseNote,
      },
      push: { route: `/dates/${plan.id}` },
    });
  }

  /** The status write has already committed. A feed failure must not become a 500. */
  private async safeRecord(input: RecordActivityInput): Promise<void> {
    try {
      await this.activity.record(input);
    } catch (error) {
      this.logger.error(
        'Activity record failed after the date plan write committed',
        error instanceof Error ? error.stack : String(error),
      );
    }
  }
}
