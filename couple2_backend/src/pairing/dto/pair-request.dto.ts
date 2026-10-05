import { IsString, Matches } from 'class-validator';

export class PairRequestDto {
  @IsString()
  @Matches(/^[A-Za-z0-9]{6}$/)
  code: string;
}
