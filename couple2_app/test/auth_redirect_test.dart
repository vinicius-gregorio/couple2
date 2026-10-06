import 'package:couple2_app/app/routing/auth_redirect.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keeps the browser route while auth is still resolving', () {
    expect(
      resolveAuthRedirect(loggedIn: null, matchedLocation: '/question'),
      isNull,
    );
    expect(
      resolveAuthRedirect(loggedIn: null, matchedLocation: '/couple'),
      isNull,
    );
  });

  test('a logged-in refresh stays on the current route', () {
    expect(
      resolveAuthRedirect(loggedIn: true, matchedLocation: '/question'),
      isNull,
    );
    expect(
      resolveAuthRedirect(loggedIn: true, matchedLocation: '/dates/new'),
      isNull,
    );
    expect(resolveAuthRedirect(loggedIn: true, matchedLocation: '/'), isNull);
  });

  test('a logged-out user is sent to login', () {
    expect(
      resolveAuthRedirect(loggedIn: false, matchedLocation: '/'),
      '/auth/login',
    );
    expect(
      resolveAuthRedirect(loggedIn: false, matchedLocation: '/couple'),
      '/auth/login',
    );
    expect(
      resolveAuthRedirect(loggedIn: false, matchedLocation: '/auth/login'),
      isNull,
    );
  });

  test('login restores a deep link instead of always going home', () {
    expect(
      resolveAuthRedirect(
        loggedIn: true,
        matchedLocation: '/auth/login',
        restoreLocation: '/question',
      ),
      '/question',
    );
    expect(
      resolveAuthRedirect(loggedIn: true, matchedLocation: '/auth/login'),
      '/',
    );
  });

  test('home and auth locations are not restored', () {
    expect(locationToRestore('/'), isNull);
    expect(locationToRestore('/auth/login'), isNull);
    expect(locationToRestore('/question'), '/question');
    expect(
      locationToRestore('/dates/new?title=Cidade'),
      '/dates/new?title=Cidade',
    );
  });
}
