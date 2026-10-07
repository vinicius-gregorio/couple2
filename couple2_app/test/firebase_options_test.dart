import 'package:couple2_app/firebase_options.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('web authDomain is the Hosting origin', () {
    expect(DefaultFirebaseOptions.web.authDomain, 'couple42-f87b6.web.app');
  });
}
