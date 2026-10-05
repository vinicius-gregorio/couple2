import { Transform } from 'class-transformer';
import { IsOptional, IsString, MaxLength, Validate } from 'class-validator';
import { DATE_PLAN_NOTE_MAX } from '../date-plan-policy';
import { FutureIsoOffsetConstraint } from './future-iso-offset.constraint';

export class CounterDatePlanDto {
  @Transform(({ value }: { value: unknown }) =>
    typeof value === 'string' ? value.trim() : value,
  )
  @IsString()
  @Validate(FutureIsoOffsetConstraint)
  scheduledAt!: string;

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
