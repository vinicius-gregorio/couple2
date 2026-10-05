import { Type } from 'class-transformer';
import {
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
} from 'class-validator';
import { DATE_PLAN_PAGE_DEFAULT } from '../date-plan-policy';
import type { DatePlanScope } from '../date-plan-policy';

export class ListDatePlansQueryDto {
  @IsIn(['upcoming', 'past'])
  scope!: DatePlanScope;

  @IsOptional()
  @IsString()
  @MaxLength(512)
  cursor?: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(50)
  limit?: number = DATE_PLAN_PAGE_DEFAULT;
}
