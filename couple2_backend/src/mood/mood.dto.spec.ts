import { BadRequestException, ValidationPipe } from '@nestjs/common';
import { CreateMoodDto } from './dto/create-mood.dto';
import { CreateNudgeDto } from './dto/create-nudge.dto';
import { MoodHistoryQueryDto } from './dto/mood-history-query.dto';
import { stripClientReceiverId } from './strip-receiver';

describe('mood and nudge DTOs', () => {
  const pipe = new ValidationPipe({
    whitelist: true,
    forbidNonWhitelisted: true,
    transform: true,
  });

  function parse<T>(metatype: new () => T, body: Record<string, unknown>) {
    return pipe.transform(body, { type: 'body', metatype }) as Promise<T>;
  }

  it('rejects a note of 141 characters and a message of 81', async () => {
    await expect(
      parse(CreateMoodDto, { mood: 'LOW', note: 'a'.repeat(141) }),
    ).rejects.toBeInstanceOf(BadRequestException);
    await expect(
      parse(CreateNudgeDto, { kind: 'HUG', message: 'b'.repeat(81) }),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('accepts a note of 140 and a message of 80', async () => {
    const mood = await parse(CreateMoodDto, {
      mood: 'GOOD',
      note: 'a'.repeat(140),
    });
    const nudge = await parse(CreateNudgeDto, {
      kind: 'MISS_YOU',
      message: 'b'.repeat(80),
    });
    expect(mood.note).toHaveLength(140);
    expect(nudge.message).toHaveLength(80);
  });

  it('drops an empty note and rejects days above 90', async () => {
    const mood = await parse(CreateMoodDto, { mood: 'OK', note: '   ' });
    expect(mood.note).toBeUndefined();
    const queryPipe = new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
    });
    await expect(
      queryPipe.transform(
        { days: '91' },
        { type: 'query', metatype: MoodHistoryQueryDto },
      ),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('ignores receiverId from the body before validation', async () => {
    const body: Record<string, unknown> = {
      kind: 'THINKING_OF_YOU',
      receiverId: 'stranger',
      message: 'oi',
    };
    await expect(parse(CreateNudgeDto, { ...body })).rejects.toBeInstanceOf(
      BadRequestException,
    );
    stripClientReceiverId(body);
    const dto = await parse(CreateNudgeDto, body);
    expect(dto.kind).toBe('THINKING_OF_YOU');
    expect(dto.message).toBe('oi');
    expect(body.receiverId).toBeUndefined();
    expect((dto as { receiverId?: string }).receiverId).toBeUndefined();
  });
});
