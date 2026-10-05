import { Transform } from 'class-transformer';
import { IsOptional, IsString, MaxLength } from 'class-validator';
import { DATE_PLAN_NOTE_MAX } from '../date-plan-policy';

export class DatePlanNoteDto {
  @IsOptional()
  @Transform(({ value }: { value: unknown }) => {
    if (typeof value !== 'string') return value;
    const trimmed = value.trim();
    return trimmed.length === 0 ? undefined : trimmed;
  })
  @IsString()
  @MaxLength(DATE_PLAN_NOTE_MAX)
  note?: string;
}
