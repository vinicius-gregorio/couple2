import { BadRequestException } from '@nestjs/common';
import type { DatePlanCursor } from './date-plan-policy';

export function encodeDatePlanCursor(item: DatePlanCursor): string {
  return Buffer.from(
    `${item.scheduledAt.toISOString()}|${item.id}`,
    'utf8',
  ).toString('base64url');
}

export function decodeDatePlanCursor(cursor: string): DatePlanCursor {
  let raw: string;
  try {
    raw = Buffer.from(cursor, 'base64url').toString('utf8');
  } catch {
    throw new BadRequestException('Invalid cursor');
  }
  const separator = raw.indexOf('|');
  if (separator <= 0) throw new BadRequestException('Invalid cursor');
  const iso = raw.slice(0, separator);
  const id = raw.slice(separator + 1);
  const scheduledAt = new Date(iso);
  if (
    !iso.endsWith('Z') ||
    Number.isNaN(scheduledAt.getTime()) ||
    id.length === 0
  ) {
    throw new BadRequestException('Invalid cursor');
  }
  return { scheduledAt, id };
}
