import { Injectable, NotFoundException } from '@nestjs/common';
import { Couple, CoupleDate, Prisma, Recurrence } from '@prisma/client';
import { calendarDateToUtc, toDateOnlyString } from '../common/calendar-date';
import type { UserWithPartner } from '../auth/strategies/jwt.strategy';
import { PrismaService } from '../prisma';
import { buildUpcoming, daysTogether } from './couple-calendar';
import {
  CreateCoupleDateDto,
  UpdateCoupleDateDto,
  UpdateCoupleDto,
} from './dto';

@Injectable()
export class CoupleService {
  constructor(private readonly prisma: PrismaService) {}

  async getCouple(user: UserWithPartner, couple: Couple) {
    const view = await this.loadView(user, couple);
    return this.toCoupleResponse(
      view.couple,
      view.partner,
      view.me,
      view.dates,
    );
  }

  async updateCouple(
    user: UserWithPartner,
    couple: Couple,
    dto: UpdateCoupleDto,
  ) {
    const data: Prisma.CoupleUpdateInput = {};
    if (dto.anniversaryDate !== undefined) {
      data.anniversaryDate = dto.anniversaryDate
        ? calendarDateToUtc(dto.anniversaryDate)
        : null;
    }
    if (typeof dto.timezone === 'string') {
      data.timezone = dto.timezone;
    }

    const updated = await this.prisma.couple.update({
      where: { id: couple.id },
      data,
    });
    return this.getCouple(user, updated);
  }

  async listDates(coupleId: string) {
    const dates = await this.prisma.coupleDate.findMany({
      where: { coupleId },
      orderBy: [{ date: 'asc' }, { createdAt: 'asc' }],
    });
    return dates.map(toCoupleDateResponse);
  }

  async createDate(userId: string, coupleId: string, dto: CreateCoupleDateDto) {
    const created = await this.prisma.coupleDate.create({
      data: {
        coupleId,
        title: dto.title.trim(),
        date: calendarDateToUtc(dto.date),
        recurrence: dto.recurrence ?? Recurrence.YEARLY,
        createdById: userId,
      },
    });
    return toCoupleDateResponse(created);
  }

  async updateDate(coupleId: string, id: string, dto: UpdateCoupleDateDto) {
    await this.findDateOrThrow(coupleId, id);
    const data: Prisma.CoupleDateUpdateInput = {};
    if (dto.title !== undefined) data.title = dto.title.trim();
    if (dto.date !== undefined) data.date = calendarDateToUtc(dto.date);
    if (dto.recurrence !== undefined) data.recurrence = dto.recurrence;

    const updated = await this.prisma.coupleDate.update({
      where: { id },
      data,
    });
    return toCoupleDateResponse(updated);
  }

  async deleteDate(coupleId: string, id: string) {
    await this.findDateOrThrow(coupleId, id);
    await this.prisma.coupleDate.delete({ where: { id } });
    return { id };
  }

  private async findDateOrThrow(
    coupleId: string,
    id: string,
  ): Promise<CoupleDate> {
    const date = await this.prisma.coupleDate.findFirst({
      where: { id, coupleId },
    });
    if (!date) {
      throw new NotFoundException('Date not found');
    }
    return date;
  }

  private async loadView(user: UserWithPartner, couple: Couple) {
    const partnerId =
      couple.userAId === user.id ? couple.userBId : couple.userAId;
    const [partner, me, dates] = await Promise.all([
      this.prisma.user.findUnique({
        where: { id: partnerId },
        select: { id: true, name: true, picture: true, birthDate: true },
      }),
      this.prisma.user.findUnique({
        where: { id: user.id },
        select: { id: true, name: true, birthDate: true },
      }),
      this.prisma.coupleDate.findMany({ where: { coupleId: couple.id } }),
    ]);

    if (!partner || !me) {
      throw new NotFoundException('Partner not found');
    }

    return { couple, partner, me, dates };
  }

  private toCoupleResponse(
    couple: Couple,
    partner: {
      id: string;
      name: string | null;
      picture: string | null;
      birthDate: Date | null;
    },
    me: { id: string; name: string | null; birthDate: Date | null },
    dates: CoupleDate[],
  ) {
    return {
      id: couple.id,
      pairedAt: couple.pairedAt,
      anniversaryDate: toDateOnlyString(couple.anniversaryDate),
      timezone: couple.timezone,
      daysTogether: daysTogether({
        anniversaryDate: couple.anniversaryDate,
        pairedAt: couple.pairedAt,
        timezone: couple.timezone,
      }),
      partner: {
        id: partner.id,
        name: partner.name,
        picture: partner.picture,
        birthDate: toDateOnlyString(partner.birthDate),
      },
      upcoming: buildUpcoming({
        timezone: couple.timezone,
        anniversaryDate: couple.anniversaryDate,
        birthdays: [
          {
            name: displayName(me.name, 'Você'),
            birthDate: me.birthDate,
            self: true,
          },
          {
            name: displayName(partner.name, 'Parceiro'),
            birthDate: partner.birthDate,
          },
        ],
        dates: dates.map((date) => ({
          id: date.id,
          title: date.title,
          date: date.date,
          recurrence: date.recurrence,
        })),
      }),
    };
  }
}

function displayName(name: string | null, fallback: string): string {
  const trimmed = name?.trim();
  return trimmed ? trimmed : fallback;
}

function toCoupleDateResponse(date: CoupleDate) {
  return {
    id: date.id,
    coupleId: date.coupleId,
    type: date.type,
    title: date.title,
    date: toDateOnlyString(date.date),
    recurrence: date.recurrence,
    createdById: date.createdById,
    createdAt: date.createdAt,
    updatedAt: date.updatedAt,
  };
}
