import { buildCoupleQuestionView } from './question-view';

describe('buildCoupleQuestionView', () => {
  const partner = {
    text: 'segredo do parceiro',
    createdAt: new Date('2026-10-05T12:00:00.000Z'),
    updatedAt: new Date('2026-10-05T12:00:00.000Z'),
  };

  it('drops partner text while the question is locked', () => {
    const view = buildCoupleQuestionView({
      id: 'cq',
      date: '2026-10-05',
      questionText: 'Oi?',
      category: 'FUN',
      unlockedAt: null,
      today: '2026-10-05',
      myAnswer: null,
      partnerAnswered: true,
      partnerAnswer: partner,
    });
    expect(view.partnerAnswered).toBe(true);
    expect(view).not.toHaveProperty('partnerAnswer');
    expect(JSON.stringify(view)).not.toContain('segredo do parceiro');
  });

  it('includes both answers after unlock', () => {
    const view = buildCoupleQuestionView({
      id: 'cq',
      date: '2026-10-05',
      questionText: 'Oi?',
      category: 'FUN',
      unlockedAt: new Date('2026-10-05T15:00:00.000Z'),
      today: '2026-10-05',
      myAnswer: partner,
      partnerAnswered: true,
      partnerAnswer: {
        ...partner,
        text: 'a outra resposta',
      },
    });
    expect(view.partnerAnswer?.text).toBe('a outra resposta');
    expect(view.unlockedAt).toBe('2026-10-05T15:00:00.000Z');
    expect(view.answerable).toBe(false);
  });
});
