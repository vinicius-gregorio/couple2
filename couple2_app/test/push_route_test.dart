import 'package:couple2_app/modules/notifications/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a notification tap follows data.route', () {
    String? opened;
    followPushRoute({'type': 'LIST_ITEM_COMPLETED', 'route': '/lists/abc'}, (
      route,
    ) {
      opened = route;
    });
    expect(opened, '/lists/abc');

    followPushRoute({'type': 'LIST_CREATED'}, (route) {
      opened = route;
    });
    expect(opened, '/lists/abc');
  });

  test('quiet minutes format 23:00 and 07:00', () {
    expect(quietMinutes(23, 0), 1380);
    expect(quietMinutes(7, 0), 420);
    expect(formatQuietMinutes(1380), '23:00');
    expect(formatQuietMinutes(420), '07:00');
  });
}
