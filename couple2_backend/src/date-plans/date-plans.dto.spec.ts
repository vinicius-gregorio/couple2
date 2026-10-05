import { BadRequestException, ValidationPipe } from '@nestjs/common';
import { CounterDatePlanDto } from './dto/counter-date-plan.dto';
import { CreateDatePlanDto } from './dto/create-date-plan.dto';
import { DatePlanNoteDto } from './dto/date-plan-note.dto';

describe('date plan DTOs', () => {
  const pipe = new ValidationPipe({
    whitelist: true,
    forbidNonWhitelisted: true,
    transform: true,
  });

  function parse<T>(metatype: new () => T, body: Record<string, unknown>) {
    return pipe.transform(body, { type: 'body', metatype }) as Promise<T>;
  }

  const future = new Date(Date.now() + 3 * 24 * 60 * 60 * 1000).toISOString();

  it('rejects a scheduledAt in the past', async () => {
    await expect(
      parse(CreateDatePlanDto, {
        title: 'Japonês',
        scheduledAt: '2020-01-01T20:00:00.000Z',
      }),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('rejects a scheduledAt without a timezone offset', async () => {
    await expect(
      parse(CreateDatePlanDto, {
        title: 'Japonês',
        scheduledAt: '2030-01-01T20:00:00',
      }),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('accepts a future ISO datetime with an offset', async () => {
    const dto = await parse(CreateDatePlanDto, {
      title: '  Japonês  ',
      scheduledAt: future,
      location: '  Centro ',
      description: '',
    });
    expect(dto.title).toBe('Japonês');
    expect(dto.location).toBe('Centro');
    expect(dto.description).toBeNull();
  });

  it('does not require a note to decline', async () => {
    const dto = await parse(DatePlanNoteDto, {});
    expect(dto.note).toBeUndefined();
  });

  it('rejects a counter in the past and a note over 140', async () => {
    await expect(
      parse(CounterDatePlanDto, {
        scheduledAt: '2020-01-01T20:00:00Z',
      }),
    ).rejects.toBeInstanceOf(BadRequestException);
    await expect(
      parse(CounterDatePlanDto, {
        scheduledAt: future,
        note: 'n'.repeat(141),
      }),
    ).rejects.toBeInstanceOf(BadRequestException);
  });
});
