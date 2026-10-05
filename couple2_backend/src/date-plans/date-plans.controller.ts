import {
  Body,
  Controller,
  Get,
  HttpCode,
  Param,
  Patch,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import type { Couple, DatePlan } from '@prisma/client';
import { GetUser } from '../auth/decorators';
import { JwtAuthGuard } from '../auth/guards';
import type { UserWithPartner } from '../auth/strategies/jwt.strategy';
import { GetCouple } from '../couple/decorators/get-couple.decorator';
import { CoupleGuard } from '../couple/guards/couple.guard';
import { GetDatePlan } from './decorators/get-date-plan.decorator';
import {
  CounterDatePlanDto,
  CreateDatePlanDto,
  DatePlanNoteDto,
  ListDatePlansQueryDto,
  UpdateDatePlanDto,
} from './dto';
import { DatePlansService } from './date-plans.service';
import { DatePlanGuard } from './guards/date-plan.guard';

@Controller('date-plans')
@UseGuards(JwtAuthGuard, CoupleGuard)
export class DatePlansController {
  constructor(private readonly datePlans: DatePlansService) {}

  @Post()
  create(
    @GetUser() user: UserWithPartner,
    @GetCouple() couple: Couple,
    @Body() dto: CreateDatePlanDto,
  ) {
    return this.datePlans.create(user, couple, dto);
  }

  @Get()
  list(@GetCouple() couple: Couple, @Query() query: ListDatePlansQueryDto) {
    return this.datePlans.list(couple, query);
  }

  @Get(':id')
  @UseGuards(DatePlanGuard)
  get(@GetCouple() couple: Couple, @GetDatePlan() plan: DatePlan) {
    return this.datePlans.get(couple.id, plan.id);
  }

  @Patch(':id')
  @UseGuards(DatePlanGuard)
  update(
    @GetUser() user: UserWithPartner,
    @GetCouple() couple: Couple,
    @Param('id') id: string,
    @Body() dto: UpdateDatePlanDto,
  ) {
    return this.datePlans.update(user, couple, id, dto);
  }

  @Post(':id/accept')
  @HttpCode(200)
  @UseGuards(DatePlanGuard)
  accept(
    @GetUser() user: UserWithPartner,
    @GetCouple() couple: Couple,
    @Param('id') id: string,
  ) {
    return this.datePlans.accept(user, couple, id);
  }

  @Post(':id/decline')
  @HttpCode(200)
  @UseGuards(DatePlanGuard)
  decline(
    @GetUser() user: UserWithPartner,
    @GetCouple() couple: Couple,
    @Param('id') id: string,
    @Body() dto: DatePlanNoteDto,
  ) {
    return this.datePlans.decline(user, couple, id, dto);
  }

  @Post(':id/counter')
  @HttpCode(200)
  @UseGuards(DatePlanGuard)
  counter(
    @GetUser() user: UserWithPartner,
    @GetCouple() couple: Couple,
    @Param('id') id: string,
    @Body() dto: CounterDatePlanDto,
  ) {
    return this.datePlans.counter(user, couple, id, dto);
  }

  @Post(':id/cancel')
  @HttpCode(200)
  @UseGuards(DatePlanGuard)
  cancel(
    @GetUser() user: UserWithPartner,
    @GetCouple() couple: Couple,
    @Param('id') id: string,
    @Body() dto: DatePlanNoteDto,
  ) {
    return this.datePlans.cancel(user, couple, id, dto);
  }

  @Post(':id/done')
  @HttpCode(200)
  @UseGuards(DatePlanGuard)
  done(
    @GetUser() user: UserWithPartner,
    @GetCouple() couple: Couple,
    @Param('id') id: string,
  ) {
    return this.datePlans.done(user, couple, id);
  }
}
