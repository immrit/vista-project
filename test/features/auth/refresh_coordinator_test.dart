import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:Vista/features/auth/data/auth_repository.dart';

AuthResponse _fakeAuthResponse(String accessToken) {
  return AuthResponse.fromJson({
    'user': {
      'id': 'user-1',
      'full_name': 'Test User',
      'account_status': 'active',
      'profile_completed': true,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    },
    'session': {
      'access_token': accessToken,
      'refresh_token': 'refresh-$accessToken',
      'token_type': 'Bearer',
      'expires_in': 900,
    },
    'is_new_user': false,
  });
}

void main() {
  group('RefreshCoordinator', () {
    // Simulates the exact race that used to log users out: two independent
    // refresh triggers (e.g. the health-check timer and the 401
    // interceptor) firing for the same device at the same time. Only ONE
    // underlying network call should ever happen; both callers must resolve
    // to that single call's result.
    test('coalesces concurrent refresh calls into a single underlying call',
        () async {
      final coordinator = RefreshCoordinator();
      var callCount = 0;
      final completer = Completer<AuthResponse>();

      Future<AuthResponse> fakeNetworkCall() {
        callCount++;
        return completer.future;
      }

      final first = coordinator.coalesce(fakeNetworkCall);
      final second = coordinator.coalesce(fakeNetworkCall);

      expect(callCount, 1,
          reason:
              'a second concurrent refresh must NOT trigger its own network call');

      completer.complete(_fakeAuthResponse('token-A'));

      final results = await Future.wait([first, second]);
      expect(results[0].session.accessToken, 'token-A');
      expect(results[1].session.accessToken, 'token-A');
      expect(identical(results[0], results[1]), isTrue);
    });

    test('a refresh call after the in-flight one completes starts fresh',
        () async {
      final coordinator = RefreshCoordinator();
      var callCount = 0;

      Future<AuthResponse> fakeNetworkCall() async {
        callCount++;
        return _fakeAuthResponse('token-$callCount');
      }

      final first = await coordinator.coalesce(fakeNetworkCall);
      final second = await coordinator.coalesce(fakeNetworkCall);

      expect(callCount, 2);
      expect(first.session.accessToken, 'token-1');
      expect(second.session.accessToken, 'token-2');
    });

    test('a failed refresh does not wedge the coordinator for later calls',
        () async {
      final coordinator = RefreshCoordinator();
      var attempt = 0;

      Future<AuthResponse> fakeNetworkCall() async {
        attempt++;
        if (attempt == 1) {
          throw Exception('network error');
        }
        return _fakeAuthResponse('token-recovered');
      }

      await expectLater(
          coordinator.coalesce(fakeNetworkCall), throwsA(isA<Exception>()));

      final recovered = await coordinator.coalesce(fakeNetworkCall);
      expect(recovered.session.accessToken, 'token-recovered');
      expect(attempt, 2);
    });
  });
}
