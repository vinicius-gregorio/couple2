import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  UseGuards,
} from '@nestjs/common';
import type { Couple } from '@prisma/client';
import { GetUser } from '../auth/decorators';
import { JwtAuthGuard } from '../auth/guards';
import type { UserWithPartner } from '../auth/strategies/jwt.strategy';
import { CoupleService } from './couple.service';
import { GetCouple } from './decorators/get-couple.decorator';
import {
  CreateCoupleDateDto,
  UpdateCoupleDateDto,
  UpdateCoupleDto,
} from './dto';
import { CoupleGuard } from './guards/couple.guard';

@Controller('couple')
@UseGuards(JwtAuthGuard, CoupleGuard)
export class CoupleController {
  constructor(private readonly coupleService: CoupleService) {}

  @Get()
  getCouple(@GetUser() user: UserWithPartner, @GetCouple() couple: Couple) {
    return this.coupleService.getCouple(user, couple);
  }

  @Patch()
  updateCouple(
    @GetUser() user: UserWithPartner,
    @GetCouple() couple: Couple,
    @Body() dto: UpdateCoupleDto,
  ) {
    return this.coupleService.updateCouple(user, couple, dto);
  }

  @Get('dates')
  listDates(@GetCouple() couple: Couple) {
    return this.coupleService.listDates(couple.id);
  }

  @Post('dates')
  createDate(
    @GetUser() user: UserWithPartner,
    @GetCouple() couple: Couple,
    @Body() dto: CreateCoupleDateDto,
  ) {
    return this.coupleService.createDate(user.id, couple.id, dto);
  }

  @Patch('dates/:id')
  updateDate(
    @GetCouple() couple: Couple,
    @Param('id') id: string,
    @Body() dto: UpdateCoupleDateDto,
  ) {
    return this.coupleService.updateDate(couple.id, id, dto);
  }

  @Delete('dates/:id')
  deleteDate(@GetCouple() couple: Couple, @Param('id') id: string) {
    return this.coupleService.deleteDate(couple.id, id);
  }
}
