import { Recurrence } from '@prisma/client';
import {
  IsEnum,
  IsOptional,
  IsString,
  MaxLength,
  MinLength,
} from 'class-validator';
import { IsCalendarDate } from '../../common/is-calendar-date';

export class UpdateCoupleDateDto {
  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(60)
  title?: string;

  @IsOptional()
  @IsCalendarDate()
  date?: string;

  @IsOptional()
  @IsEnum(Recurrence)
  recurrence?: Recurrence;
}
