import {
  ValidatorConstraint,
  ValidatorConstraintInterface,
} from 'class-validator';
import { ISO_WITH_OFFSET } from '../date-plan-time';

@ValidatorConstraint({ name: 'futureIsoOffset', async: false })
export class FutureIsoOffsetConstraint implements ValidatorConstraintInterface {
  validate(value: unknown): boolean {
    if (typeof value !== 'string' || !ISO_WITH_OFFSET.test(value)) {
      return false;
    }
    const date = new Date(value);
    return !Number.isNaN(date.getTime()) && date.getTime() > Date.now();
  }

  defaultMessage(): string {
    return 'scheduledAt must be a future ISO-8601 datetime with a timezone offset';
  }
}
