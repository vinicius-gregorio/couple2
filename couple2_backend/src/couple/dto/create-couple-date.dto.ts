import { Recurrence } from '@prisma/client';
import {
  IsEnum,
  IsOptional,
  IsString,
  MaxLength,
  MinLength,
} from 'class-validator';
import { IsCalendarDate } from '../../common/is-calendar-date';

export class CreateCoupleDateDto {
  @IsString()
  @MinLength(1)
  @MaxLength(60)
  title: string;

  @IsCalendarDate()
  date: string;

  @IsOptional()
  @IsEnum(Recurrence)
  recurrence?: Recurrence;
}
