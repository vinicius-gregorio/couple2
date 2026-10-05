import { ValidationPipe } from '@nestjs/common';
import { UpdateNotificationPreferencesDto } from './dto/update-notification-preferences.dto';

describe('UpdateNotificationPreferencesDto', () => {
  const pipe = new ValidationPipe({
    whitelist: true,
    forbidNonWhitelisted: true,
    transform: true,
  });

  function parse(body: Record<string, unknown>) {
    return pipe.transform(body, {
      type: 'body',
      metatype: UpdateNotificationPreferencesDto,
    }) as Promise<UpdateNotificationPreferencesDto>;
  }

  it('accepts a category toggle and null quiet hours', async () => {
    const dto = await parse({
      lists: false,
      quietStartMin: null,
      quietEndMin: 420,
    });
    expect(dto).toEqual(
      expect.objectContaining({
        lists: false,
        quietStartMin: null,
        quietEndMin: 420,
      }),
    );
  });

  it('rejects an unknown field and a minute outside the day', async () => {
    await expect(parse({ extra: true })).rejects.toThrow();
    await expect(parse({ quietStartMin: 2000 })).rejects.toThrow();
  });
});
