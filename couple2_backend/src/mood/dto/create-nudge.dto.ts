import { NudgeKind } from '@prisma/client';
import { Transform } from 'class-transformer';
import { IsEnum, IsOptional, IsString, MaxLength } from 'class-validator';
import { trimToUndefined } from './create-mood.dto';
import { NUDGE_MESSAGE_MAX } from '../mood-policy';

export class CreateNudgeDto {
  @IsEnum(NudgeKind)
  kind!: NudgeKind;

  @IsOptional()
  @Transform(({ value }: { value: unknown }) => trimToUndefined(value))
  @IsString()
  @MaxLength(NUDGE_MESSAGE_MAX)
  message?: string;
}
