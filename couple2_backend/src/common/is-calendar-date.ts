import {
  registerDecorator,
  ValidationArguments,
  ValidationOptions,
} from 'class-validator';
import { parseCalendarDate, todayUtcDateOnly } from './calendar-date';

export function IsCalendarDate(validationOptions?: ValidationOptions) {
  return (object: object, propertyName: string) => {
    registerDecorator({
      name: 'isCalendarDate',
      target: object.constructor,
      propertyName,
      options: validationOptions,
      validator: {
        validate(value: unknown) {
          return typeof value === 'string' && parseCalendarDate(value) !== null;
        },
        defaultMessage(args?: ValidationArguments) {
          return `${args?.property ?? 'date'} must be a real calendar date (YYYY-MM-DD)`;
        },
      },
    });
  };
}

/** birthDate may be today, but not a later calendar day (compared in UTC). */
export function IsNotFutureDate(validationOptions?: ValidationOptions) {
  return (object: object, propertyName: string) => {
    registerDecorator({
      name: 'isNotFutureDate',
      target: object.constructor,
      propertyName,
      options: validationOptions,
      validator: {
        validate(value: unknown) {
          if (typeof value !== 'string' || parseCalendarDate(value) === null) {
            return false;
          }
          return value <= todayUtcDateOnly();
        },
        defaultMessage(args?: ValidationArguments) {
          return `${args?.property ?? 'date'} cannot be in the future`;
        },
      },
    });
  };
}
