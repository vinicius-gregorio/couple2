import 'package:couple2_app/modules/mood/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('age label stays warm and does not count streaks', () {
    final now = DateTime(2026, 10, 5, 18);
    expect(
      moodAgeLabel(now.subtract(const Duration(seconds: 20)), now),
      'agora',
    );
    expect(moodAgeLabel(now.subtract(const Duration(hours: 2)), now), 'há 2 h');
    expect(moodDayLabel(now, now), 'Hoje');
    expect(
      moodDayLabel(now.subtract(const Duration(days: 1, hours: 1)), now),
      'Ontem',
    );
    expect(suggestCaringNudge(MoodLevel.low), isTrue);
    expect(suggestCaringNudge(MoodLevel.bad), isTrue);
    expect(suggestCaringNudge(MoodLevel.good), isFalse);
    expect(suggestCaringNudge(null), isFalse);
  });
}
