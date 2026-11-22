import 'dart:async';

import 'package:didit_sdk/sdk_flutter.dart';
import 'package:didit_sdk/sdk_flutter_method_channel.dart';
import 'package:didit_sdk/sdk_flutter_platform_interface.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// Flushes the microtasks and event-loop turns the platform channel needs
/// between a Dart call and the handler on the native side receiving it.
Future<void> _settle() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

DiditConfig _config(String languageCode) =>
    DiditConfig(languageCode: languageCode);

/// A platform whose call throws before returning a future, the way a bridge
/// that fails to marshal its arguments does.
class _SynchronouslyThrowingPlatform
    with MockPlatformInterfaceMixin
    implements SdkFlutterPlatform {
  int calls = 0;

  @override
  Future<Map<String, dynamic>> startVerification(
    String token,
    Map<String, dynamic>? config,
  ) {
    calls++;
    throw StateError('bridge unavailable');
  }

  @override
  Future<Map<String, dynamic>> startVerificationWithWorkflow(
    String workflowId,
    String? vendorData,
    Map<String, dynamic>? config,
  ) {
    calls++;
    throw StateError('bridge unavailable');
  }

  @override
  Future<Map<String, dynamic>> submitTransaction(
    String transactionToken,
    Map<String, dynamic> transaction,
    Map<String, dynamic> options,
  ) => throw UnimplementedError();

  @override
  Future<Map<String, dynamic>> getTransaction(
    String transactionToken,
    String transactionId,
    Map<String, dynamic> options,
  ) => throw UnimplementedError();

  @override
  void setTransactionUpdateHandler(
    void Function(String callId, Map<String, dynamic> result)? handler,
  ) {}

  @override
  Future<Map<String, dynamic>> presentBankLink(
    String token,
    Map<String, dynamic> options,
  ) => throw StateError('bridge unavailable');

  @override
  Future<Map<String, dynamic>?> resumeBankLink() => throw StateError(
    'bridge unavailable',
  );

  @override
  Future<bool> handleBankLinkReturn(String url) => throw StateError(
    'bridge unavailable',
  );

  @override
  Stream<BankLinkEvent> get bankLinkEvents => throw StateError(
    'bridge unavailable',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('didit_sdk');
  final completed = <String, dynamic>{
    'type': 'completed',
    'sessionId': 'test-session',
    'status': 'Approved',
  };

  late List<MethodCall> nativeCalls;
  late List<Completer<Map<String, dynamic>>> inFlight;

  void answerFromNative(Map<String, dynamic> result) =>
      inFlight.removeAt(0).complete(result);

  setUp(() {
    nativeCalls = <MethodCall>[];
    inFlight = <Completer<Map<String, dynamic>>>[];
    SdkFlutterPlatform.instance = MethodChannelSdkFlutter();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) {
          nativeCalls.add(call);
          final completer = Completer<Map<String, dynamic>>();
          inFlight.add(completer);
          return completer.future;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'an identical startVerification call joins the running verification',
    () async {
      final first = DiditSdk.startVerification(
        'token-a',
        config: _config('es'),
      );
      final second = DiditSdk.startVerification(
        'token-a',
        config: _config('es'),
      );
      await _settle();

      expect(nativeCalls, hasLength(1));
      expect(nativeCalls.single.method, 'startVerification');

      answerFromNative(completed);

      final results = await Future.wait([first, second]);
      expect(results[0], isA<VerificationCompleted>());
      expect(results[1], isA<VerificationCompleted>());
      expect(identical(results[0], results[1]), isTrue);
      expect(
        (results[1] as VerificationCompleted).session.sessionId,
        'test-session',
      );
    },
  );

  test('an identical startVerificationWithWorkflow call joins the running '
      'verification', () async {
    final first = DiditSdk.startVerificationWithWorkflow(
      'workflow-a',
      vendorData: 'user-1',
    );
    final second = DiditSdk.startVerificationWithWorkflow(
      'workflow-a',
      vendorData: 'user-1',
    );
    await _settle();

    expect(nativeCalls, hasLength(1));
    expect(nativeCalls.single.method, 'startVerificationWithWorkflow');

    answerFromNative(completed);

    final results = await Future.wait([first, second]);
    expect(identical(results[0], results[1]), isTrue);
    expect(results[1], isA<VerificationCompleted>());
  });

  test('a different verification started while one is running is failed '
      'without reaching native', () async {
    final first = DiditSdk.startVerification('token-a');
    await _settle();
    expect(nativeCalls, hasLength(1));

    final otherToken = DiditSdk.startVerification('token-b');
    final otherConfig = DiditSdk.startVerification(
      'token-a',
      config: _config('fr'),
    );
    final otherWorkflow = DiditSdk.startVerificationWithWorkflow('workflow-a');
    await _settle();

    // Nothing else may reach the platform while the first verification runs.
    expect(nativeCalls, hasLength(1));

    final blocked = <VerificationResult>[
      await otherToken,
      await otherConfig,
      await otherWorkflow,
    ];

    for (final result in blocked) {
      expect(result, isA<VerificationFailed>());
      final failed = result as VerificationFailed;
      expect(failed.error.type, VerificationErrorType.unknown);
      expect(failed.error.message, 'A verification is already in progress.');
      expect(failed.session, isNull);
    }
    expect(nativeCalls, hasLength(1));

    answerFromNative(completed);
    expect(await first, isA<VerificationCompleted>());
  });

  test('starts a new verification once the previous one settles', () async {
    final first = DiditSdk.startVerification('token-a');
    await _settle();
    answerFromNative(<String, dynamic>{'type': 'cancelled'});
    expect(await first, isA<VerificationCancelled>());

    final second = DiditSdk.startVerification('token-a');
    await _settle();
    expect(nativeCalls, hasLength(2));

    answerFromNative(completed);
    expect(await second, isA<VerificationCompleted>());
  });

  test(
    'rejects every joined caller and releases when the native call fails',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) {
            nativeCalls.add(call);
            return Future<Map<String, dynamic>>.error(
              PlatformException(
                code: 'native_failure',
                message: 'native failure',
              ),
            );
          });

      final first = DiditSdk.startVerification('token-a');
      final second = DiditSdk.startVerification('token-a');
      // Listen before the failure lands, so the error is never unhandled.
      final expectations = <Future<void>>[
        expectLater(first, throwsA(isA<PlatformException>())),
        expectLater(second, throwsA(isA<PlatformException>())),
      ];

      await _settle();
      expect(nativeCalls, hasLength(1));

      await Future.wait(expectations);

      nativeCalls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) {
            nativeCalls.add(call);
            final completer = Completer<Map<String, dynamic>>();
            inFlight.add(completer);
            return completer.future;
          });

      final third = DiditSdk.startVerification('token-b');
      await _settle();
      expect(nativeCalls, hasLength(1));

      answerFromNative(completed);
      expect(await third, isA<VerificationCompleted>());
    },
  );

  test('releases when the platform call throws synchronously', () async {
    final throwing = _SynchronouslyThrowingPlatform();
    SdkFlutterPlatform.instance = throwing;

    await expectLater(
      DiditSdk.startVerification('token-a'),
      throwsA(isA<StateError>()),
    );
    expect(throwing.calls, 1);

    SdkFlutterPlatform.instance = MethodChannelSdkFlutter();
    final after = DiditSdk.startVerification('token-a');
    await _settle();
    expect(nativeCalls, hasLength(1));

    answerFromNative(completed);
    expect(await after, isA<VerificationCompleted>());
  });
}
