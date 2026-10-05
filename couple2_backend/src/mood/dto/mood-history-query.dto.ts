import { Type } from 'class-transformer';
import { IsInt, IsOptional, Max, Min } from 'class-validator';
import { MOOD_HISTORY_MAX_DAYS } from '../mood-policy';

export class MoodHistoryQueryDto {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(MOOD_HISTORY_MAX_DAYS)
  days?: number;
}
