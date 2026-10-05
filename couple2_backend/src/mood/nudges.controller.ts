import {
  Body,
  Controller,
  Get,
  HttpCode,
  Param,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import type { Couple } from '@prisma/client';
import { GetUser } from '../auth/decorators';
import { JwtAuthGuard } from '../auth/guards';
import type { UserWithPartner } from '../auth/strategies/jwt.strategy';
import { GetCouple } from '../couple/decorators/get-couple.decorator';
import { CoupleGuard } from '../couple/guards/couple.guard';
import { CreateNudgeDto, ReceivedNudgesQueryDto } from './dto';
import { IgnoreClientReceiverGuard } from './ignore-client-receiver.guard';
import { NudgesService } from './nudges.service';

@Controller('nudges')
@UseGuards(JwtAuthGuard, CoupleGuard)
export class NudgesController {
  constructor(private readonly nudges: NudgesService) {}

  @Post()
  @UseGuards(IgnoreClientReceiverGuard)
  create(
    @GetUser() user: UserWithPartner,
    @GetCouple() couple: Couple,
    @Body() dto: CreateNudgeDto,
  ) {
    return this.nudges.create(user, couple, dto);
  }

  @Get('received')
  received(
    @GetUser() user: UserWithPartner,
    @GetCouple() couple: Couple,
    @Query() query: ReceivedNudgesQueryDto,
  ) {
    return this.nudges.received(user, couple, query);
  }

  @Post(':id/seen')
  @HttpCode(200)
  seen(
    @Param('id') id: string,
    @GetUser() user: UserWithPartner,
    @GetCouple() couple: Couple,
  ) {
    return this.nudges.markSeen(user, couple, id);
  }
}
