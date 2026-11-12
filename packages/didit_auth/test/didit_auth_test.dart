import 'dart:convert';

import 'package:didit_auth/didit_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _key = 'pk_test_abc123';
const _redirect = 'https://app.example.com/didit/callback';

const _sessionJson = <String, Object?>{
  'userId': 'user-1',
  'sessionId': 'session-1',
  'applicationId': 'app-1',
  'vendorData': null,
  'email': 'person@example.com',
  'emailVerified': true,
  'phone': null,
  'methods': ['passkey'],
  'mfaVerified': false,
  'verified': {
    'level': 'full',
    'claims': {'age_over_18': true},
  },
  'organizations': [
    {'id': 'org-1', 'name': 'Example', 'role': 'admin'},
  ],
  'expiresAt': '2030-01-02T03:04:05Z',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('didit_auth');
  const auth = DiditAuth(publishableKey: _key, redirectUri: _redirect);
  final calls = <MethodCall>[];

  void answer(Future<Object?> Function(MethodCall call) handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) {
          calls.add(call);
          return handler(call);
        });
  }

  setUp(calls.clear);

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('signIn', () {
    test('sends the application and parses the session', () async {
      answer((_) async => jsonEncode(_sessionJson));

      final session = await auth.signIn();

      expect(calls.single.method, 'signIn');
      expect(calls.single.arguments, {
        'publishableKey': _key,
        'redirectUri': _redirect,
      });
      expect(session.userId, 'user-1');
      expect(session.sessionId, 'session-1');
      expect(session.applicationId, 'app-1');
      expect(session.vendorData, isNull);
      expect(session.email, 'person@example.com');
      expect(session.emailVerified, isTrue);
      expect(session.phone, isNull);
      expect(session.methods, ['passkey']);
      expect(session.mfaVerified, isFalse);
      expect(session.verified, {
        'level': 'full',
        'claims': {'age_over_18': true},
      });
      expect(session.organizations.single.id, 'org-1');
      expect(session.organizations.single.name, 'Example');
      expect(session.organizations.single.role, 'admin');
      expect(session.expiresAt, DateTime.utc(2030, 1, 2, 3, 4, 5));
    });

    test('a cancelled sign-in is a cancelled exception', () async {
      answer(
        (_) async => throw PlatformException(
          code: 'cancelled',
          message: 'The sign-in was cancelled.',
        ),
      );

      await expectLater(
        auth.signIn(),
        throwsA(
          isA<DiditAuthException>()
              .having((e) => e.code, 'code', DiditAuthErrorCodes.cancelled)
              .having((e) => e.message, 'message', contains('cancelled'))
              .having((e) => e.status, 'status', isNull)
              .having((e) => e.fields, 'fields', isNull)
              .having((e) => e.retryAfter, 'retryAfter', isNull),
        ),
      );
    });

    test('a null answer is a server error', () async {
      answer((_) async => null);

      await expectLater(
        auth.signIn(),
        throwsA(
          isA<DiditAuthException>().having(
            (e) => e.code,
            'code',
            DiditAuthErrorCodes.serverError,
          ),
        ),
      );
    });

    test('a malformed session is a server error', () async {
      answer((_) async => jsonEncode({..._sessionJson, 'userId': 7}));

      await expectLater(
        auth.signIn(),
        throwsA(
          isA<DiditAuthException>()
              .having((e) => e.code, 'code', DiditAuthErrorCodes.serverError)
              .having((e) => e.message, 'message', contains('userId')),
        ),
      );
    });

    test('text that is not a JSON object is a server error', () async {
      answer((_) async => '[1, 2]');

      await expectLater(
        auth.signIn(),
        throwsA(
          isA<DiditAuthException>().having(
            (e) => e.code,
            'code',
            DiditAuthErrorCodes.serverError,
          ),
        ),
      );

      answer((_) async => 'not json');

      await expectLater(
        auth.signIn(),
        throwsA(
          isA<DiditAuthException>().having(
            (e) => e.code,
            'code',
            DiditAuthErrorCodes.serverError,
          ),
        ),
      );
    });
  });

  test(
    'signInWithPasskey sends the application and parses the session',
    () async {
      answer((_) async => jsonEncode(_sessionJson));

      final session = await auth.signInWithPasskey();

      expect(calls.single.method, 'signInWithPasskey');
      expect(calls.single.arguments, {
        'publishableKey': _key,
        'redirectUri': _redirect,
      });
      expect(session.sessionId, 'session-1');
    },
  );

  test('registerPasskey returns the passkey id', () async {
    answer((_) async => 'passkey-1');

    expect(await auth.registerPasskey(), 'passkey-1');
    expect(calls.single.method, 'registerPasskey');
    expect(calls.single.arguments, {
      'publishableKey': _key,
      'redirectUri': _redirect,
    });
  });

  group('currentSession', () {
    test('does not force by default', () async {
      answer((_) async => jsonEncode(_sessionJson));

      final session = await auth.currentSession();

      expect(calls.single.method, 'currentSession');
      expect(calls.single.arguments, {
        'publishableKey': _key,
        'redirectUri': _redirect,
        'force': false,
      });
      expect(session?.userId, 'user-1');
    });

    test('passes force through', () async {
      answer((_) async => jsonEncode(_sessionJson));

      await auth.currentSession(force: true);

      expect((calls.single.arguments as Map)['force'], isTrue);
    });

    test('is null when nobody is signed in', () async {
      answer((_) async => null);

      expect(await auth.currentSession(), isNull);
    });
  });

  group('getToken', () {
    test('returns the access token', () async {
      answer((_) async => 'token-1');

      expect(await auth.getToken(), 'token-1');
      expect(calls.single.method, 'getToken');
      expect(calls.single.arguments, {
        'publishableKey': _key,
        'redirectUri': _redirect,
      });
    });

    test('is null when signed out', () async {
      answer((_) async => null);

      expect(await auth.getToken(), isNull);
    });
  });

  test('signOut completes', () async {
    answer((_) async => null);

    await auth.signOut();

    expect(calls.single.method, 'signOut');
    expect(calls.single.arguments, {
      'publishableKey': _key,
      'redirectUri': _redirect,
    });
  });

  group('stepUp', () {
    const resultJson = <String, Object?>{
      'id': 'step-up-1',
      'status': 'approved',
      'approved': true,
      'rule': 'payout',
      'method': 'liveness',
    };

    test('a payout sends the amount and currency', () async {
      answer((_) async => jsonEncode(resultJson));

      final result = await auth.stepUp(
        const DiditPayoutStepUp(amount: '900.00', currency: 'EUR'),
      );

      expect(calls.single.method, 'stepUp');
      expect(calls.single.arguments, {
        'publishableKey': _key,
        'redirectUri': _redirect,
        'action': 'payout',
        'amount': '900.00',
        'currency': 'EUR',
      });
      expect(
        result,
        const DiditStepUpResult(
          id: 'step-up-1',
          status: 'approved',
          approved: true,
          rule: 'payout',
          method: 'liveness',
        ),
      );
    });

    test('a payout without a currency omits it', () async {
      answer((_) async => jsonEncode(resultJson));

      await auth.stepUp(const DiditPayoutStepUp(amount: '5.00'));

      expect(calls.single.arguments, {
        'publishableKey': _key,
        'redirectUri': _redirect,
        'action': 'payout',
        'amount': '5.00',
      });
    });

    test('bank and contact send only the action', () async {
      answer((_) async => jsonEncode(resultJson));

      await auth.stepUp(const DiditBankStepUp());
      await auth.stepUp(const DiditContactStepUp());

      expect(calls.map((call) => call.arguments), [
        {'publishableKey': _key, 'redirectUri': _redirect, 'action': 'bank'},
        {'publishableKey': _key, 'redirectUri': _redirect, 'action': 'contact'},
      ]);
    });

    test('no rule asked: not required, no id', () async {
      answer(
        (_) async => jsonEncode({
          'id': null,
          'status': 'not_required',
          'approved': true,
          'rule': null,
          'method': null,
        }),
      );

      final result = await auth.stepUp(const DiditBankStepUp());

      expect(result.id, isNull);
      expect(result.status, 'not_required');
      expect(result.approved, isTrue);
      expect(result.rule, isNull);
      expect(result.method, isNull);
    });
  });

  group('errors', () {
    const nativeCodes = [
      'cancelled',
      'invalid_state',
      'not_signed_in',
      'passkey_cancelled',
      'passkey_unavailable',
      'browser_unavailable',
      'storage_unavailable',
      'rate_limited',
      'invalid_publishable_key',
      'invalid_redirect_uri',
      'invalid_request',
      'network_error',
      'server_error',
      'unspecified',
      // Codes of the Didit API pass through unchanged.
      'invalid_grant',
      'method_unavailable',
      'reauthentication_required',
    ];

    for (final code in nativeCodes) {
      test('$code keeps its code and message', () async {
        answer(
          (_) async => throw PlatformException(code: code, message: 'm $code'),
        );

        await expectLater(
          auth.getToken(),
          throwsA(
            isA<DiditAuthException>()
                .having((e) => e.code, 'code', code)
                .having((e) => e.message, 'message', 'm $code'),
          ),
        );
      });
    }

    test('the constants are the documented codes', () {
      expect({
        DiditAuthErrorCodes.cancelled,
        DiditAuthErrorCodes.invalidState,
        DiditAuthErrorCodes.notSignedIn,
        DiditAuthErrorCodes.passkeyCancelled,
        DiditAuthErrorCodes.passkeyUnavailable,
        DiditAuthErrorCodes.browserUnavailable,
        DiditAuthErrorCodes.storageUnavailable,
        DiditAuthErrorCodes.rateLimited,
        DiditAuthErrorCodes.invalidPublishableKey,
        DiditAuthErrorCodes.invalidRedirectUri,
        DiditAuthErrorCodes.invalidRequest,
        DiditAuthErrorCodes.networkError,
        DiditAuthErrorCodes.serverError,
        DiditAuthErrorCodes.unspecified,
      }, nativeCodes.sublist(0, 14).toSet());
      expect(DiditAuthErrorCodes.unavailable, 'ERR_DIDIT_AUTH_UNAVAILABLE');
    });

    test('status, fields and retryAfter come from the details', () async {
      answer(
        (_) async => throw PlatformException(
          code: 'rate_limited',
          message: 'Slow down.',
          details: {
            'status': 429,
            'retryAfter': 12,
            'fields': {
              'return_to': ['invalid_redirect_uri', 'required'],
            },
          },
        ),
      );

      await expectLater(
        auth.getToken(),
        throwsA(
          isA<DiditAuthException>()
              .having((e) => e.code, 'code', 'rate_limited')
              .having((e) => e.status, 'status', 429)
              .having((e) => e.retryAfter, 'retryAfter', 12)
              .having((e) => e.fields, 'fields', {
                'return_to': ['invalid_redirect_uri', 'required'],
              }),
        ),
      );
    });

    test('details that are not shaped as documented are ignored', () async {
      answer(
        (_) async => throw PlatformException(
          code: 'server_error',
          details: {
            'status': 'x',
            'retryAfter': 'y',
            'fields': {'a': 'b'},
          },
        ),
      );

      await expectLater(
        auth.getToken(),
        throwsA(
          isA<DiditAuthException>()
              .having((e) => e.status, 'status', isNull)
              .having((e) => e.retryAfter, 'retryAfter', isNull)
              .having((e) => e.fields, 'fields', isNull)
              .having((e) => e.message, 'message', 'server_error'),
        ),
      );
    });

    test('a platform without the plugin is unavailable', () async {
      // No handler is set, so the channel throws MissingPluginException.
      await expectLater(
        auth.signIn(),
        throwsA(
          isA<DiditAuthUnavailableException>().having(
            (e) => e.code,
            'code',
            'ERR_DIDIT_AUTH_UNAVAILABLE',
          ),
        ),
      );
    });

    test('toString names the code', () {
      expect(
        const DiditAuthException('cancelled', message: 'Closed.').toString(),
        'DiditAuthException(cancelled): Closed.',
      );
    });
  });
}
