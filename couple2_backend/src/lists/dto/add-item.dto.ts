import { IsObject, IsOptional, IsString, MinLength } from 'class-validator';

export class AddItemDto {
  @IsString()
  @MinLength(1)
  content: string;

  @IsOptional()
  @IsObject()
  metadata?: Record<string, unknown>;
}
