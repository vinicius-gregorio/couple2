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

  it('comforts on a hard day and never quotes the note', () => {
    const copy = buildPushCopy({
      type: ActivityType.MOOD_SHARED,
      actorName: 'Bia',
      payload: { mood: 'LOW', note: 'segredo doloroso' },
    });
    expect(copy.body).toBe('Bia não está num dia muito bom 💛');
    expect(copy.body).not.toContain('segredo');
  });

  it('collapses a burst of nudges and keeps a single one specific', () => {
    const one = buildPushCopy({
      type: ActivityType.NUDGE_SENT,
      actorName: 'Bia',
      payload: { kind: 'HUG', recentCount: 1, message: 'aqui' },
    });
    expect(one.body).toContain('Bia mandou um abraço');
    expect(one.body).toContain('aqui');

    const burst = buildPushCopy({
      type: ActivityType.NUDGE_SENT,
      actorName: 'Bia',
      payload: { kind: 'HUG', recentCount: 4, message: 'aqui' },
    });
    expect(burst.body).toBe('Bia mandou 4 carinhos');
    expect(burst.body).not.toContain('aqui');
  });
});

describe('buildPushCopy date plans', () => {
  it('uses the couple-timezone label and leaves the note out of the push', () => {
    const proposed = buildPushCopy({
      type: ActivityType.DATE_PLAN_PROPOSED,
      actorName: 'Bia',
      payload: {
        title: 'Japonês',
        whenLabel: 'sexta-feira, 20:00',
        responseNote: 'não conta',
      },
    });
    expect(proposed.body).toBe('Bia propôs "Japonês" para sexta-feira, 20:00');
    expect(proposed.body).not.toContain('não conta');

    const countered = buildPushCopy({
      type: ActivityType.DATE_PLAN_COUNTERED,
      actorName: 'Bia',
      payload: { title: 'Japonês', whenLabel: 'sábado, 19:00' },
    });
    expect(countered.body).toContain('sugeriu "Japonês"');
    expect(countered.body).toContain('sábado, 19:00');
  });
});
