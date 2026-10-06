import { BadRequestException } from '@nestjs/common';
import { Prisma } from '@prisma/client';

const OCCASIONS = new Set([
  'BIRTHDAY',
  'ANNIVERSARY',
  'CHRISTMAS',
  'VALENTINES',
  'OTHER',
]);

const STATUSES = new Set(['IDEA', 'BOUGHT']);

const FIELDS = new Set([
  'price',
  'currency',
  'url',
  'occasion',
  'coupleDateId',
  'status',
]);

/**
 * GIFT_IDEAS item metadata. Every field is optional.
 * isCompleted on the row means the gift was delivered; status stops at BOUGHT.
 */
export function validateGiftItemMetadata(
  metadata: unknown,
): Prisma.InputJsonValue | undefined {
  if (metadata == null) return undefined;
  if (typeof metadata !== 'object' || Array.isArray(metadata)) {
    throw new BadRequestException('Invalid gift metadata');
  }

  const input = metadata as Record<string, unknown>;
  for (const key of Object.keys(input)) {
    if (!FIELDS.has(key)) {
      throw new BadRequestException(`Unknown gift metadata field: ${key}`);
    }
  }

  const out: Record<string, Prisma.InputJsonValue> = {};

  if ('price' in input) {
    const price = input.price;
    if (typeof price !== 'number' || !Number.isFinite(price) || price < 0) {
      throw new BadRequestException(
        'Gift price must be a number greater than or equal to 0',
      );
    }
    out.price = price;
  }

  if ('currency' in input) {
    if (input.currency !== 'BRL') {
      throw new BadRequestException('Gift currency must be BRL');
    }
    out.currency = 'BRL';
  }

  if ('url' in input) {
    if (typeof input.url !== 'string' || !isHttpUrl(input.url)) {
      throw new BadRequestException('Gift url must be an http or https URL');
    }
    out.url = input.url;
  }

  if ('occasion' in input) {
    if (typeof input.occasion !== 'string' || !OCCASIONS.has(input.occasion)) {
      throw new BadRequestException('Invalid gift occasion');
    }
    out.occasion = input.occasion;
  }

  if ('coupleDateId' in input) {
    if (
      typeof input.coupleDateId !== 'string' ||
      input.coupleDateId.trim() === ''
    ) {
      throw new BadRequestException('Gift coupleDateId must be a string');
    }
    out.coupleDateId = input.coupleDateId;
  }

  if ('status' in input) {
    if (typeof input.status !== 'string' || !STATUSES.has(input.status)) {
      throw new BadRequestException('Gift status must be IDEA or BOUGHT');
    }
    out.status = input.status;
  }

  return out;
}

function isHttpUrl(value: string): boolean {
  try {
    const url = new URL(value);
    return url.protocol === 'http:' || url.protocol === 'https:';
  } catch {
    return false;
  }
}
