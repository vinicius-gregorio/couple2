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
import { AnswerQuestionDto, HistoryQueryDto } from './dto';
import { QuestionsService } from './questions.service';

@Controller('questions')
@UseGuards(JwtAuthGuard, CoupleGuard)
export class QuestionsController {
  constructor(private readonly questions: QuestionsService) {}

  @Get('today')
  today(@GetUser() user: UserWithPartner, @GetCouple() couple: Couple) {
    return this.questions.getToday(user.id, couple);
  }

  @Get('history')
  history(
    @GetUser() user: UserWithPartner,
    @GetCouple() couple: Couple,
    @Query() query: HistoryQueryDto,
  ) {
    return this.questions.history(user.id, couple, query);
  }

  @Post(':coupleQuestionId/answer')
  @HttpCode(200)
  answer(
    @Param('coupleQuestionId') coupleQuestionId: string,
    @GetUser() user: UserWithPartner,
    @GetCouple() couple: Couple,
    @Body() dto: AnswerQuestionDto,
  ) {
    return this.questions.answer(user.id, couple, coupleQuestionId, dto.text);
  }
}
