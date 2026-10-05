import { MoodLevel } from '@prisma/client';
import { Transform } from 'class-transformer';
import { IsEnum, IsOptional, IsString, MaxLength } from 'class-validator';
import { MOOD_NOTE_MAX } from '../mood-policy';

export class CreateMoodDto {
  @IsEnum(MoodLevel)
  mood!: MoodLevel;

  @IsOptional()
  @Transform(({ value }: { value: unknown }) => trimToUndefined(value))
  @IsString()
  @MaxLength(MOOD_NOTE_MAX)
  note?: string;
}

export function trimToUndefined(value: unknown): unknown {
  if (typeof value !== 'string') return value;
  const trimmed = value.trim();
  return trimmed.length === 0 ? undefined : trimmed;
}
