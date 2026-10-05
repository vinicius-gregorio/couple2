import { ActivityType } from '@prisma/client';
import { buildPushCopy } from './push-copy';

describe('buildPushCopy questions', () => {
  it('asks the partner to answer before showing the text', () => {
    const copy = buildPushCopy({
      type: ActivityType.QUESTION_ANSWERED,
      actorName: 'Bia',
      payload: {},
    });
    expect(copy.body).toContain('Bia respondeu');
    expect(copy.body.toLowerCase()).toContain('responda para ver');
  });

  it('tells the first partner the question is unlocked', () => {
    const copy = buildPushCopy({
      type: ActivityType.QUESTION_UNLOCKED,
      actorName: 'Bia',
      payload: {},
    });
    expect(copy.title.toLowerCase()).toContain('desbloqueada');
    expect(copy.body.toLowerCase()).toContain('desbloqueada');
  });
});
