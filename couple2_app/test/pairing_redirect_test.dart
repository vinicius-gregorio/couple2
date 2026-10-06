import 'package:couple2_app/app/routing/pairing_redirect.dart';
import 'package:couple2_app/app/routing/session_redirect.dart';
import 'package:couple2_app/app/session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const unpaired = Session(
    id: 'a',
    email: 'a@example.com',
    name: 'Ana',
    isPaired: false,
    pairingCode: 'ABC123',
  );
  const paired = Session(
    id: 'a',
    email: 'a@example.com',
    name: 'Ana',
    isPaired: true,
    coupleId: 'couple-1',
    partnerId: 'b',
  );

  test('an unpaired login goes to pairing, not home', () {
    expect(
      resolveAppRedirect(
        loggedIn: true,
        matchedLocation: '/auth/login',
        sessionReady: true,
        needsPairing: sessionNeedsPairing(unpaired),
      ),
      '/pairing',
    );
    expect(
      resolveAppRedirect(
        loggedIn: true,
        matchedLocation: '/',
        sessionReady: true,
        needsPairing: true,
      ),
      '/pairing',
    );
    expect(
      resolveAppRedirect(
        loggedIn: true,
        matchedLocation: '/lists',
        restoreLocation: '/lists',
        sessionReady: true,
        needsPairing: true,
      ),
      '/pairing',
    );
  });

  test('pairing routes stay put while the account is unpaired', () {
    expect(
      resolvePairingRedirect(needsPairing: true, matchedLocation: '/pairing'),
      isNull,
    );
    expect(
      resolvePairingRedirect(
        needsPairing: true,
        matchedLocation: '/pairing/enter',
      ),
      isNull,
    );
    expect(
      resolvePairingRedirect(
        needsPairing: true,
        matchedLocation: '/pairing/waiting',
      ),
      isNull,
    );
  });

  test('a paired account is sent home from the pairing flow', () {
    expect(
      resolveAppRedirect(
        loggedIn: true,
        matchedLocation: '/pairing/waiting',
        sessionReady: true,
        needsPairing: sessionNeedsPairing(paired),
      ),
      '/',
    );
    expect(
      resolveAppRedirect(
        loggedIn: true,
        matchedLocation: '/',
        sessionReady: true,
        needsPairing: false,
      ),
      isNull,
    );
    expect(
      resolveAppRedirect(
        loggedIn: true,
        matchedLocation: '/auth/login',
        restoreLocation: '/question',
        sessionReady: true,
        needsPairing: false,
      ),
      '/question',
    );
  });

  test('login waits until the session says if a partner is missing', () {
    expect(
      sessionReadyForPairing(const AsyncLoading(), loggedIn: true),
      isFalse,
    );
    expect(
      sessionReadyForPairing(const AsyncData<Session?>(null), loggedIn: true),
      isFalse,
    );
    expect(
      resolveAppRedirect(
        loggedIn: true,
        matchedLocation: '/auth/login',
        sessionReady: false,
        needsPairing: false,
      ),
      isNull,
    );
    expect(
      resolveAppRedirect(
        loggedIn: true,
        matchedLocation: '/lists',
        sessionReady: false,
        needsPairing: true,
      ),
      isNull,
    );
  });

  test('a logged-out user still goes to login', () {
    expect(
      resolveAppRedirect(
        loggedIn: false,
        matchedLocation: '/',
        sessionReady: false,
        needsPairing: true,
      ),
      '/auth/login',
    );
    expect(
      resolveAppRedirect(
        loggedIn: null,
        matchedLocation: '/pairing',
        sessionReady: false,
        needsPairing: true,
      ),
      isNull,
    );
  });

  test('partnerId alone is enough to leave the pairing gate', () {
    const legacy = Session(
      id: 'a',
      email: 'a@example.com',
      name: 'Ana',
      isPaired: true,
      partnerId: 'b',
    );
    expect(sessionNeedsPairing(legacy), isFalse);
    expect(sessionNeedsPairing(unpaired), isTrue);
    expect(sessionNeedsPairing(null), isFalse);
  });
}
