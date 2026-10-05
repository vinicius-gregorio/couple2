import { Transform } from 'class-transformer';
import {
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
  MinLength,
  Validate,
} from 'class-validator';
import {
  DATE_PLAN_DESCRIPTION_MAX,
  DATE_PLAN_LOCATION_MAX,
  DATE_PLAN_TITLE_MAX,
} from '../date-plan-policy';
import { FutureIsoOffsetConstraint } from './future-iso-offset.constraint';

export class CreateDatePlanDto {
  @Transform(({ value }: { value: unknown }) => trimString(value))
  @IsString()
  @MinLength(1)
  @MaxLength(DATE_PLAN_TITLE_MAX)
  title!: string;

  @Transform(({ value }: { value: unknown }) => trimString(value))
  @IsString()
  @Validate(FutureIsoOffsetConstraint)
  scheduledAt!: string;

  @IsOptional()
  @Transform(({ value }: { value: unknown }) => emptyToNull(value))
  @IsString()
  @MaxLength(DATE_PLAN_LOCATION_MAX)
  location?: string | null;

  @IsOptional()
  @Transform(({ value }: { value: unknown }) => emptyToNull(value))
  @IsString()
  @MaxLength(DATE_PLAN_DESCRIPTION_MAX)
  description?: string | null;

  @IsOptional()
  @Transform(({ value }: { value: unknown }) => emptyToUndefined(value))
  @IsUUID()
  sourceListItemId?: string;
}

function trimString(value: unknown): unknown {
  return typeof value === 'string' ? value.trim() : value;
}

function emptyToNull(value: unknown): unknown {
  if (value == null) return value;
  if (typeof value !== 'string') return value;
  const trimmed = value.trim();
  return trimmed.length === 0 ? null : trimmed;
}

function emptyToUndefined(value: unknown): unknown {
  if (typeof value !== 'string') return value;
  const trimmed = value.trim();
  return trimmed.length === 0 ? undefined : trimmed;
}
