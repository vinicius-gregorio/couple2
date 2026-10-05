import { IsOptional, IsTimeZone, ValidateIf } from 'class-validator';
import { IsCalendarDate } from '../../common/is-calendar-date';

export class UpdateCoupleDto {
  /** YYYY-MM-DD. Null clears the date so the app can show the setup CTA again. */
  @ValidateIf((_, value) => value !== null && value !== undefined)
  @IsCalendarDate()
  anniversaryDate?: string | null;

  @IsOptional()
  @IsTimeZone()
  timezone?: string;
}
