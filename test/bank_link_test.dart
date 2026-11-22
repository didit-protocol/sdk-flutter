import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:didit_sdk/sdk_flutter.dart';
import 'package:didit_sdk/sdk_flutter_method_channel.dart';
import 'package:didit_sdk/sdk_flutter_platform_interface.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The payload keys of every event (`link-contract/events.md`, section 1).
/// Payloads carry ids only: no name, token, email or account number.
const _eventPayloadKeys = <String, Set<String>>{
  'opened': {'link_id', 'mode', 'access', 'presentation'},
  'consent_shown': {'link_id', 'consent_version'},
  'consent_accepted': {'link_id', 'consent_version'},
  'institution_selected': {'institution_id', 'country'},
  'bank_redirect': {'via'},
  'bank_returned': {'result'},
  'accounts_selected': {'count'},
  'success': {'link_id', 'connection_id', 'check_id'},
  'exit': {'reason', 'step'},
  'error': {'code'},
};

/// Fields that must never reach a host through an event model.
const _forbiddenEventKeys = {
  'name',
  'full_name',
  'token',
  'client_token',
  'account_number',
  'iban',
  'email',
  'mask',
};

Map<String, dynamic> _success({bool resumed = false}) => <String, dynamic>{
  'type': 'success',
  'linkId': '0b9c4f1e-6a2d-4e8b-9f31-7c5d2e1a8b40',
  'connectionId': '8c2f0b47-3d19-4a52-9e6b-1f4d7c0a2b93',
  'checkId': '5a1e7d93-2b48-4c60-8f17-9d3e6b2c4a08',
  'resumed': resumed,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('didit_sdk');
  const eventChannel = EventChannel('didit_sdk/bank_link_events');

  late List<MethodCall> nativeCalls;
  Map<String, dynamic>? nextResult;
  Map<String, dynamic>? nextResume;
  Object? nextError;
  bool nextHandled;

  setUp(() {
    nativeCalls = <MethodCall>[];
    nextResult = null;
    nextResume = null;
    nextError = null;
    nextHandled = false;
    SdkFlutterPlatform.instance = MethodChannelSdkFlutter();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          nativeCalls.add(call);
          final error = nextError;
          if (error != null) throw error;
          return switch (call.method) {
            'presentBankLink' => nextResult,
            'resumeBankLink' => nextResume,
            'handleBankLinkReturn' => nextHandled,
            _ => null,
          };
        });
  });

  tearDown(() async {
    await Future<void>.delayed(Duration.zero);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(eventChannel, null);
  });

  group('presentBankLink', () {
    test('forwards the token and options and settles on a success', () async {
      nextResult = _success();

      final result = await DiditSdk.presentBankLink(
        'blt_Hs8Pa4Rb6Ye0Gf2Jc7Qm3Zx9Vd2Lc5W',
        options: const BankLinkOptions(
          config: DiditConfig(languageCode: 'es', fontFamily: 'Inter'),
        ),
      );

      final call = nativeCalls.single;
      expect(call.method, 'presentBankLink');
      expect(call.arguments['token'], 'blt_Hs8Pa4Rb6Ye0Gf2Jc7Qm3Zx9Vd2Lc5W');
      final config = call.arguments['options']['config'] as Map;
      expect(config['languageCode'], 'es');
      expect(config['fontFamily'], 'Inter');

      expect(result, isA<BankLinkSuccess>());
      final success = result as BankLinkSuccess;
      expect(success.linkId, '0b9c4f1e-6a2d-4e8b-9f31-7c5d2e1a8b40');
      expect(success.connectionId, '8c2f0b47-3d19-4a52-9e6b-1f4d7c0a2b93');
      expect(success.checkId, '5a1e7d93-2b48-4c60-8f17-9d3e6b2c4a08');
      expect(success.resumed, false);
    });

    test('settles the device language when the host passes no config', () async {
      nextResult = _success();

      await DiditSdk.presentBankLink('blt_Hs8Pa4Rb6Ye0Gf2Jc7Qm3Zx9Vd2Lc5W');

      final config = nativeCalls.single.arguments['options']['config'] as Map;
      expect(config['languageCode'], isNotNull);
    });

    for (final (wire, expected) in <(String, BankLinkExitReason)>[
      ('closed', BankLinkExitReason.closed),
      ('cancelled', BankLinkExitReason.cancelled),
      ('bank_unavailable', BankLinkExitReason.bankUnavailable),
      ('expired', BankLinkExitReason.expired),
      ('failed', BankLinkExitReason.failed),
    ]) {
      test('settles on a $wire exit', () async {
        nextResult = <String, dynamic>{
          'type': 'exit',
          'reason': wire,
          'step': 'bank_hop',
          'resumed': false,
        };

        final result = await DiditSdk.presentBankLink(
          'blt_Hs8Pa4Rb6Ye0Gf2Jc7Qm3Zx9Vd2Lc5W',
        );

        expect(result, isA<BankLinkExit>());
        final exit = result as BankLinkExit;
        expect(exit.reason, expected);
        expect(exit.reason.wireName, wire);
        expect(exit.step, 'bank_hop');
        expect(exit.resumed, false);
      });
    }

    test('reads a reason it does not know as failed, never as an error', () async {
      nextResult = <String, dynamic>{
        'type': 'exit',
        'reason': 'a_reason_from_a_newer_sdk',
        'step': null,
        'resumed': false,
      };

      final result = await DiditSdk.presentBankLink(
        'blt_Hs8Pa4Rb6Ye0Gf2Jc7Qm3Zx9Vd2Lc5W',
      );

      expect((result as BankLinkExit).reason, BankLinkExitReason.failed);
      expect(result.step, isNull);
    });

    test('an empty bridge answer is a failed exit, not an exception', () async {
      nextResult = null;

      final result = await DiditSdk.presentBankLink(
        'blt_Hs8Pa4Rb6Ye0Gf2Jc7Qm3Zx9Vd2Lc5W',
      );

      expect(result, isA<BankLinkExit>());
      expect((result as BankLinkExit).reason, BankLinkExitReason.failed);
    });

    test('a platform failure is a failed exit, not a thrown error', () async {
      nextError = PlatformException(code: 'unavailable', message: 'no native');

      final result = await DiditSdk.presentBankLink(
        'blt_Hs8Pa4Rb6Ye0Gf2Jc7Qm3Zx9Vd2Lc5W',
      );

      expect(result, isA<BankLinkExit>());
      expect((result as BankLinkExit).reason, BankLinkExitReason.failed);
    });

    test('a second link while one is open fails cleanly', () async {
      final first = Completer<Map<String, dynamic>>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            (MethodCall call) {
              nativeCalls.add(call);
              return first.future;
            },
          );

      final open = DiditSdk.presentBankLink(
        'blt_Hs8Pa4Rb6Ye0Gf2Jc7Qm3Zx9Vd2Lc5W',
      );
      final second = await DiditSdk.presentBankLink(
        'blt_Wd2Lm5Tn8Vc1Ks4Pa6Rb0Hq3Zx9Ye7Jc',
      );

      expect(nativeCalls, hasLength(1));
      expect(second, isA<BankLinkExit>());
      expect((second as BankLinkExit).reason, BankLinkExitReason.failed);

      first.complete(_success());
      expect(await open, isA<BankLinkSuccess>());

      // The guard is released once the first link settles.
      nextResult = _success();
      expect(
        await DiditSdk.presentBankLink('blt_Hs8Pa4Rb6Ye0Gf2Jc7Qm3Zx9Vd2Lc5W'),
        isA<BankLinkSuccess>(),
      );
    });
  });

  group('resumeBankLink', () {
    test('returns null when nothing is pending', () async {
      nextResume = null;

      expect(await DiditSdk.resumeBankLink(), isNull);
      expect(nativeCalls.single.method, 'resumeBankLink');
    });

    test('returns the replayed result with resumed: true', () async {
      nextResume = _success(resumed: true);

      final result = await DiditSdk.resumeBankLink();

      expect(result, isA<BankLinkSuccess>());
      expect((result! as BankLinkSuccess).resumed, true);
    });

    test('replays an exit with resumed: true', () async {
      nextResume = <String, dynamic>{
        'type': 'exit',
        'reason': 'closed',
        'step': 'accounts',
        'resumed': true,
      };

      final result = await DiditSdk.resumeBankLink();

      expect(result, isA<BankLinkExit>());
      final exit = result! as BankLinkExit;
      expect(exit.reason, BankLinkExitReason.closed);
      expect(exit.step, 'accounts');
      expect(exit.resumed, true);
    });

    test('a bridge that cannot answer reads as nothing to resume', () async {
      nextError = PlatformException(code: 'unavailable');

      expect(await DiditSdk.resumeBankLink(), isNull);
    });
  });

  group('bankLinkEvents', () {
    test('delivers each event once with the exact keys', () async {
      final native = await _FakeNativeEvents.open(
        eventChannel,
        DiditSdk.bankLinkEvents,
      );
      addTearDown(native.subscription.cancel);
      final events = native.received;

      final payloads = <String, Map<String, Object?>>{
        'opened': {
          'link_id': '0b9c4f1e-6a2d-4e8b-9f31-7c5d2e1a8b40',
          'mode': 'connect',
          'access': 'ongoing',
          'presentation': 'flutter',
        },
        'consent_shown': {'link_id': 'link-1', 'consent_version': '2026-11-22.1'},
        'consent_accepted': {
          'link_id': 'link-1',
          'consent_version': '2026-11-22.1',
        },
        'institution_selected': {
          'institution_id': 'es-banco-norte',
          'country': 'ES',
        },
        'bank_redirect': {'via': 'popup'},
        'bank_returned': {'result': 'ok'},
        'accounts_selected': {'count': 2},
        'success': {
          'link_id': 'link-1',
          'connection_id': 'connection-1',
          'check_id': null,
        },
        'exit': {'reason': 'cancelled', 'step': 'accounts'},
        'error': {'code': 'unknown'},
      };

      for (final entry in payloads.entries) {
        native.sender.success(<String, Object?>{
          'name': entry.key,
          'data': entry.value,
        });
      }
      await Future<void>.delayed(Duration.zero);

      expect(events.map((event) => event.name), payloads.keys);
      for (final event in events) {
        expect(
          event.data.keys.toSet(),
          _eventPayloadKeys[event.name],
          reason: event.name,
        );
        expect(
          event.data.keys.where(_forbiddenEventKeys.contains),
          isEmpty,
          reason: event.name,
        );
      }
    });

    test('keeps an event name it does not know', () async {
      final native = await _FakeNativeEvents.open(
        eventChannel,
        DiditSdk.bankLinkEvents,
      );
      addTearDown(native.subscription.cancel);

      native.sender.success(<String, Object?>{
        'name': 'a_new_event',
        'data': <String, Object?>{'link_id': 'link-1'},
      });
      await Future<void>.delayed(Duration.zero);

      expect(native.received.single.name, 'a_new_event');
      expect(native.received.single.data, {'link_id': 'link-1'});
    });
  });

  group('handleBankLinkReturn', () {
    test('forwards the address unchanged and reports it was handled', () async {
      nextHandled = true;
      const url =
          'https://app.example.com/accounts/connect'
          '?didit_resume=rsc_0b9c4f1e6a2d4e8b9f317c5d2e1a8b40'
          '.7Hq3Zx9Wd2Lm5Tn8Vc1Ks4Pa6Rb0Uv3';

      expect(await DiditSdk.handleBankLinkReturn(url), isTrue);
      expect(nativeCalls.single.method, 'handleBankLinkReturn');
      expect(nativeCalls.single.arguments['url'], url);
    });

    test('reports an address that was not a bank return', () async {
      nextHandled = false;

      expect(
        await DiditSdk.handleBankLinkReturn('https://app.example.com/other'),
        isFalse,
      );
    });
  });

  group('the identifier formats file', () {
    // The service pins every identifier it hands to a client in one file; each
    // platform copies it and proves its own validation accepts every example. A
    // validator may be looser than the file, never stricter: the web SDK's
    // stricter resume-code pattern is what broke its flow on staging.
    final fixture = File(
      'test/fixtures/bank_link_contract/formats.json',
    ).readAsStringSync();
    final formats = (jsonDecode(fixture) as Map<String, dynamic>)['formats']
        as List<dynamic>;

    test('is the contract’s own file and every example matches its pattern', () {
      expect(formats, hasLength(14));
      for (final entry in formats.cast<Map<String, dynamic>>()) {
        final example = entry['example'] as String;
        expect(
          RegExp(entry['pattern'] as String).hasMatch(example),
          isTrue,
          reason: '${entry['name']}: $example',
        );
      }
    });

    test('every example is accepted as a token, unchanged', () async {
      for (final entry in formats.cast<Map<String, dynamic>>()) {
        final example = entry['example'] as String;
        nextResult = _success();
        nativeCalls.clear();

        await DiditSdk.presentBankLink(example);

        expect(
          nativeCalls.single.arguments['token'],
          example,
          reason: '${entry['name']}',
        );
      }
    });

    test('every example survives a bank-return address, dot included', () async {
      for (final entry in formats.cast<Map<String, dynamic>>()) {
        final example = entry['example'] as String;
        for (final url in <String>[
          'https://app.example.com/bank/return?didit_resume=$example',
          'didit-sdk://bank/return?didit_resume=$example',
          'https://app.example.com/accounts/connect?state=$example&link_ref=$example',
        ]) {
          nextHandled = true;
          nativeCalls.clear();

          expect(await DiditSdk.handleBankLinkReturn(url), isTrue);
          expect(
            nativeCalls.single.arguments['url'],
            url,
            reason: '${entry['name']} in $url',
          );
        }
      }
    });

    test('the resume code the backend mints carries a dot', () {
      final resume = formats.cast<Map<String, dynamic>>().firstWhere(
        (entry) => entry['name'] == 'resume_code',
      );
      final example = resume['example'] as String;

      expect(example, startsWith('rsc_'));
      expect(example.split('.'), hasLength(2));
      expect(example.substring(example.indexOf('.') + 1), isNotEmpty);
    });
  });
}

/// The native side of the wrapper's event channel, with a subscription on the
/// Dart stream so events sent through [sender] reach it.
class _FakeNativeEvents {
  _FakeNativeEvents._(this.sender, this.subscription, this.received);

  final MockStreamHandlerEventSink sender;
  final StreamSubscription<BankLinkEvent> subscription;
  final List<BankLinkEvent> received;

  static Future<_FakeNativeEvents> open(
    EventChannel channel,
    Stream<BankLinkEvent> events,
  ) async {
    final received = <BankLinkEvent>[];
    final sink = Completer<MockStreamHandlerEventSink>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(
          channel,
          MockStreamHandler.inline(
            onListen: (arguments, native) => sink.complete(native),
          ),
        );
    final subscription = events.listen(received.add);
    final sender = await sink.future.timeout(const Duration(seconds: 5));
    return _FakeNativeEvents._(sender, subscription, received);
  }
}
