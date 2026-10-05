import { ListType } from '@prisma/client';
import { IsEnum, IsString, MinLength } from 'class-validator';

export class CreateListDto {
  @IsEnum(ListType)
  type: ListType;

  @IsString()
  @MinLength(1)
  name: string;
}
