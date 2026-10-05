import { Body, Controller, Get, Post, Query, UseGuards } from '@nestjs/common';
import type { Couple } from '@prisma/client';
import { GetUser } from '../auth/decorators';
import { JwtAuthGuard } from '../auth/guards';
import type { UserWithPartner } from '../auth/strategies/jwt.strategy';
import { GetCouple } from '../couple/decorators/get-couple.decorator';
import { CoupleGuard } from '../couple/guards/couple.guard';
import { CreateMoodDto, MoodHistoryQueryDto } from './dto';
import { MoodService } from './mood.service';

@Controller('mood')
@UseGuards(JwtAuthGuard, CoupleGuard)
export class MoodController {
  constructor(private readonly mood: MoodService) {}

  @Post()
  create(
    @GetUser() user: UserWithPartner,
    @GetCouple() couple: Couple,
    @Body() dto: CreateMoodDto,
  ) {
    return this.mood.create(user, couple, dto);
  }

  @Get('current')
  current(@GetUser() user: UserWithPartner, @GetCouple() couple: Couple) {
    return this.mood.current(user, couple);
  }

  @Get('history')
  history(
    @GetUser() user: UserWithPartner,
    @GetCouple() couple: Couple,
    @Query() query: MoodHistoryQueryDto,
  ) {
    return this.mood.history(user, couple, query);
  }
}
