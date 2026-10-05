import { ListType, ListVisibility } from '@prisma/client';
import { IsEnum, IsOptional, IsString, MinLength } from 'class-validator';

export class CreateListDto {
  @IsEnum(ListType)
  type: ListType;

  @IsString()
  @MinLength(1)
  name: string;

  /** Omitted GIFT_IDEAS lists become PRIVATE_FROM_PARTNER in the service. */
  @IsOptional()
  @IsEnum(ListVisibility)
  visibility?: ListVisibility;
}
