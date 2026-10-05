import { ValidateIf } from 'class-validator';
import { IsCalendarDate, IsNotFutureDate } from '../../common/is-calendar-date';

export class UpdateMeDto {
  /** YYYY-MM-DD. Null clears the birthday. A future date is rejected. */
  @ValidateIf((_, value) => value !== null && value !== undefined)
  @IsCalendarDate()
  @IsNotFutureDate()
  birthDate?: string | null;
}
