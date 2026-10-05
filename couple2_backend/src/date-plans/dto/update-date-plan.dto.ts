import { Transform } from 'class-transformer';
import {
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
  MinLength,
  Validate,
  ValidateIf,
} from 'class-validator';
import {
  DATE_PLAN_DESCRIPTION_MAX,
  DATE_PLAN_LOCATION_MAX,
  DATE_PLAN_TITLE_MAX,
} from '../date-plan-policy';
import { FutureIsoOffsetConstraint } from './future-iso-offset.constraint';

export class UpdateDatePlanDto {
  @IsOptional()
  @Transform(({ value }: { value: unknown }) =>
    typeof value === 'string' ? value.trim() : value,
  )
  @IsString()
  @MinLength(1)
  @MaxLength(DATE_PLAN_TITLE_MAX)
  title?: string;

  @IsOptional()
  @Transform(({ value }: { value: unknown }) =>
    typeof value === 'string' ? value.trim() : value,
  )
  @IsString()
  @Validate(FutureIsoOffsetConstraint)
  scheduledAt?: string;

  @IsOptional()
  @Transform(({ value }: { value: unknown }) => emptyToNull(value))
  @ValidateIf((_, value) => value !== null)
  @IsString()
  @MaxLength(DATE_PLAN_LOCATION_MAX)
  location?: string | null;

  @IsOptional()
  @Transform(({ value }: { value: unknown }) => emptyToNull(value))
  @ValidateIf((_, value) => value !== null)
  @IsString()
  @MaxLength(DATE_PLAN_DESCRIPTION_MAX)
  description?: string | null;

  @IsOptional()
  @Transform(({ value }: { value: unknown }) => emptyToNull(value))
  @ValidateIf((_, value) => value !== null)
  @IsUUID()
  sourceListItemId?: string | null;
}

function emptyToNull(value: unknown): unknown {
  if (value == null) return value;
  if (typeof value !== 'string') return value;
  const trimmed = value.trim();
  return trimmed.length === 0 ? null : trimmed;
}
