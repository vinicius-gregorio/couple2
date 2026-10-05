import { Transform } from 'class-transformer';
import { IsBoolean, IsInt, IsOptional, Max, Min } from 'class-validator';

function optionalMinute({ value }: { value: unknown }): unknown {
  if (value === null || value === undefined || value === '') return value;
  return Number(value);
}

export class UpdateNotificationPreferencesDto {
  @IsOptional()
  @IsBoolean()
  pushEnabled?: boolean;

  @IsOptional()
  @IsBoolean()
  lists?: boolean;

  @IsOptional()
  @IsBoolean()
  importantDates?: boolean;

  @IsOptional()
  @IsBoolean()
  dailyQuestion?: boolean;

  @IsOptional()
  @IsBoolean()
  mood?: boolean;

  @IsOptional()
  @IsBoolean()
  nudges?: boolean;

  @IsOptional()
  @IsBoolean()
  datePlans?: boolean;

  /** Minutes from local midnight. Null clears the bound. Example: 1380 = 23:00. */
  @IsOptional()
  @Transform(optionalMinute)
  @IsInt()
  @Min(0)
  @Max(1439)
  quietStartMin?: number | null;

  @IsOptional()
  @Transform(optionalMinute)
  @IsInt()
  @Min(0)
  @Max(1439)
  quietEndMin?: number | null;
}
