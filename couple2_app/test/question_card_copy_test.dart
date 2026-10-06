import 'package:couple2_app/modules/daily_question/domain/question_card_copy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('home card has three states', () {
    final unanswered = todayCardCopy(
      answeredByMe: false,
      unlocked: false,
      partnerName: 'Bia',
    );
    expect(unanswered.kind, TodayCardKind.unanswered);
    expect(unanswered.title, 'Responda a pergunta de hoje');
    expect(unanswered.grayPartnerAvatar, isFalse);

    final waiting = todayCardCopy(
      answeredByMe: true,
      unlocked: false,
      partnerName: 'Bia',
    );
    expect(waiting.kind, TodayCardKind.waiting);
    expect(waiting.title, 'Você respondeu, aguardando Bia');
    expect(waiting.grayPartnerAvatar, isTrue);

    final partnerFirst = todayCardCopy(
      answeredByMe: false,
      unlocked: false,
      partnerName: 'Ana Smoke',
      partnerAnswered: true,
    );
    expect(partnerFirst.kind, TodayCardKind.partnerAnswered);
    expect(partnerFirst.title, 'Ana Smoke já respondeu');
    expect(partnerFirst.grayPartnerAvatar, isFalse);
    expect(
      partnerAlreadyAnsweredLine('Ana Smoke'),
      'Ana Smoke já respondeu. A resposta aparece quando você responder.',
    );
    expect(partnerAlreadyAnsweredLine('  '), contains('Seu par'));
    expect(partnerAlreadyAnsweredLine('Ana Smoke'), isNot(contains('varanda')));

    final unlocked = todayCardCopy(
      answeredByMe: true,
      unlocked: true,
      partnerName: 'Bia',
    );
    expect(unlocked.kind, TodayCardKind.unlocked);
    expect(unlocked.title, 'Desbloqueada! Veja a resposta de Bia');
    expect(unlocked.grayPartnerAvatar, isFalse);
  });

  test(
    'history shows Responder only for unanswered rows inside the window',
    () {
      expect(
        showHistoryAnswerCta(answerable: true, answeredByMe: false),
        isTrue,
      );
      expect(
        showHistoryAnswerCta(answerable: true, answeredByMe: true),
        isFalse,
      );
      expect(
        showHistoryAnswerCta(answerable: false, answeredByMe: false),
        isFalse,
      );
      expect(
        showHistoryEditCta(
          answerable: true,
          answeredByMe: true,
          unlocked: false,
        ),
        isTrue,
      );
      expect(
        showHistoryEditCta(
          answerable: true,
          answeredByMe: true,
          unlocked: true,
        ),
        isFalse,
      );
    },
  );

  test('formats a calendar date without shifting the day', () {
    expect(formatCalendarDate('2026-10-05'), '05/10/2026');
  });
}
