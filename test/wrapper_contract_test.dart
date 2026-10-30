import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:didit_sdk/sdk_flutter.dart';
import 'package:didit_sdk/sdk_flutter_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// A platform double that records what the Dart wrapper forwards and returns
/// the map the native bridge would send back.
class RecordingSdkPlatform
    with MockPlatformInterfaceMixin
    implements SdkFlutterPlatform {
  Map<String, dynamic>? verificationConfig;
  Map<String, dynamic>? workflowConfig;
  Map<String, dynamic>? transactionOptions;
  Map<String, dynamic>? getTransactionOptions;
  Map<String, dynamic>? transactionPayload;
  String? workflowId;
  String? vendorData;
  Map<String, dynamic> verificationResponse = <String, dynamic>{};
  Map<String, dynamic> workflowResponse = <String, dynamic>{};
  void Function(String callId, Map<String, dynamic> result)?
  transactionUpdateHandler;

  @override
  Future<Map<String, dynamic>> startVerification(
    String token,
    Map<String, dynamic>? config,
  ) async {
    verificationConfig = config;
    return verificationResponse;
  }

  @override
  Future<Map<String, dynamic>> startVerificationWithWorkflow(
    String workflowId,
    String? vendorData,
    Map<String, dynamic>? config,
  ) async {
    this.workflowId = workflowId;
    this.vendorData = vendorData;
    workflowConfig = config;
    return workflowResponse;
  }

  @override
  Future<Map<String, dynamic>> submitTransaction(
    String transactionToken,
    Map<String, dynamic> transaction,
    Map<String, dynamic> options,
  ) async {
    transactionPayload = transaction;
    transactionOptions = options;
    return <String, dynamic>{
      'transactionId': 'txn-1',
      'status': 'AWAITING_USER',
      'actionRequired': <String, dynamic>{
        'type': 'wallet_ownership',
        'widgetSessionId': 'widget-1',
      },
    };
  }

  @override
  Future<Map<String, dynamic>> getTransaction(
    String transactionToken,
    String transactionId,
    Map<String, dynamic> options,
  ) async {
    getTransactionOptions = options;
    return <String, dynamic>{'transactionId': transactionId};
  }

  @override
  void setTransactionUpdateHandler(
    void Function(String callId, Map<String, dynamic> result)? handler,
  ) {
    transactionUpdateHandler = handler;
  }
}

const _everyOption = DiditConfig(
  languageCode: 'de',
  showLanguageSelector: true,
  fontFamily: 'Inter',
  loggingEnabled: true,
  showCloseButton: false,
  showExitConfirmation: false,
  closeOnComplete: true,
  defaultDocumentCamera: CameraLens.front,
  defaultLivenessCamera: CameraLens.back,
  showDocumentCameraSwitchButton: false,
  showLivenessCameraSwitchButton: false,
);

const _everyOptionMap = <String, dynamic>{
  'languageCode': 'de',
  'showLanguageSelector': true,
  'fontFamily': 'Inter',
  'loggingEnabled': true,
  'showCloseButton': false,
  'showExitConfirmation': false,
  'closeOnComplete': true,
  'defaultDocumentCamera': 'front',
  'defaultLivenessCamera': 'back',
  'showDocumentCameraSwitchButton': false,
  'showLivenessCameraSwitchButton': false,
};

void main() {
  final platform = RecordingSdkPlatform();

  setUp(() {
    SdkFlutterPlatform.instance = platform;
    platform.verificationConfig = null;
    platform.workflowConfig = null;
    platform.transactionOptions = null;
    platform.getTransactionOptions = null;
    platform.transactionPayload = null;
    platform.workflowId = null;
    platform.vendorData = null;
    platform.verificationResponse = <String, dynamic>{};
    platform.workflowResponse = <String, dynamic>{};
  });

  group('configuration forwarding', () {
    test('the token entry point forwards every documented option', () async {
      await DiditSdk.startVerification('token', config: _everyOption);

      expect(platform.verificationConfig, _everyOptionMap);
    });

    test('the workflow entry point forwards every documented option', () async {
      await DiditSdk.startVerificationWithWorkflow(
        'workflow',
        vendorData: 'user-1',
        config: _everyOption,
      );

      expect(platform.workflowConfig, _everyOptionMap);
      expect(platform.workflowId, 'workflow');
      expect(platform.vendorData, 'user-1');
    });

    test('unset native defaults are omitted and the documented defaults '
        'are sent explicitly', () async {
      await DiditSdk.startVerification('token', config: const DiditConfig());

      final config = platform.verificationConfig!;
      expect(config['showLanguageSelector'], false);
      expect(config['loggingEnabled'], false);
      expect(config['showCloseButton'], true);
      expect(config['showExitConfirmation'], true);
      expect(config['closeOnComplete'], false);
      expect(config['showDocumentCameraSwitchButton'], true);
      expect(config['showLivenessCameraSwitchButton'], true);
      expect(config.containsKey('fontFamily'), false);
      expect(config.containsKey('defaultDocumentCamera'), false);
      expect(config.containsKey('defaultLivenessCamera'), false);
    });

    testWidgets('the device locale keeps the native language variants', (
      tester,
    ) async {
      addTearDown(tester.binding.platformDispatcher.clearLocaleTestValue);
      const cases = <Locale, String>{
        Locale('zh', 'TW'): 'zh-TW',
        Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hant',
          countryCode: 'HK',
        ): 'zh-TW',
        Locale('zh', 'CN'): 'zh-CN',
        Locale('zh', 'SG'): 'zh-CN',
        Locale('zh'): 'zh',
        Locale('pt', 'BR'): 'pt-BR',
        Locale('pt', 'PT'): 'pt',
      };

      for (final entry in cases.entries) {
        tester.binding.platformDispatcher.localeTestValue = entry.key;

        await DiditSdk.startVerification('token');

        expect(
          platform.verificationConfig?['languageCode'],
          entry.value,
          reason: '${entry.key}',
        );
      }
    });

    testWidgets('an explicit language wins over the device locale', (
      tester,
    ) async {
      tester.binding.platformDispatcher.localeTestValue = const Locale('es');
      addTearDown(tester.binding.platformDispatcher.clearLocaleTestValue);

      await DiditSdk.startVerification(
        'token',
        config: const DiditConfig(languageCode: 'he'),
      );

      expect(platform.verificationConfig?['languageCode'], 'he');
    });
  });

  group('verification callbacks', () {
    test('a completed session reaches Dart with its id and status', () async {
      platform.verificationResponse = <String, dynamic>{
        'type': 'completed',
        'sessionId': 'session-1',
        'status': 'Approved',
      };

      final result = await DiditSdk.startVerification('token');

      expect(result, isA<VerificationCompleted>());
      final completed = result as VerificationCompleted;
      expect(completed.session.sessionId, 'session-1');
      expect(completed.session.status, VerificationStatus.approved);
    });

    test('a cancelled session with a session reaches Dart', () async {
      platform.workflowResponse = <String, dynamic>{
        'type': 'cancelled',
        'sessionId': 'session-2',
        'status': 'Pending',
      };

      final result = await DiditSdk.startVerificationWithWorkflow('workflow');

      expect(result, isA<VerificationCancelled>());
      final cancelled = result as VerificationCancelled;
      expect(cancelled.session?.sessionId, 'session-2');
      expect(cancelled.session?.status, VerificationStatus.pending);
    });

    test('a cancelled session without a session reaches Dart', () async {
      platform.verificationResponse = <String, dynamic>{'type': 'cancelled'};

      final result = await DiditSdk.startVerification('token');

      expect(result, isA<VerificationCancelled>());
      expect((result as VerificationCancelled).session, isNull);
    });

    test('every native error type reaches the matching Dart enum', () async {
      const errorTypes = <String, VerificationErrorType>{
        'sessionExpired': VerificationErrorType.sessionExpired,
        'networkError': VerificationErrorType.networkError,
        'cameraAccessDenied': VerificationErrorType.cameraAccessDenied,
        'notInitialized': VerificationErrorType.notInitialized,
        'apiError': VerificationErrorType.apiError,
        'retryBlocked': VerificationErrorType.retryBlocked,
      };

      for (final entry in errorTypes.entries) {
        platform.verificationResponse = <String, dynamic>{
          'type': 'failed',
          'errorType': entry.key,
          'errorMessage': 'message for ${entry.key}',
          'sessionId': 'session-3',
          'status': 'Declined',
        };

        final result = await DiditSdk.startVerification('token');

        expect(result, isA<VerificationFailed>());
        final failed = result as VerificationFailed;
        expect(failed.error.type, entry.value);
        expect(failed.error.message, 'message for ${entry.key}');
        expect(failed.session?.sessionId, 'session-3');
        expect(failed.session?.status, VerificationStatus.declined);
      }
    });

    test(
      'an unknown error type and missing message fall back safely',
      () async {
        platform.verificationResponse = <String, dynamic>{
          'type': 'failed',
          'errorType': 'somethingNew',
        };

        final result = await DiditSdk.startVerification('token');

        expect(result, isA<VerificationFailed>());
        final failed = result as VerificationFailed;
        expect(failed.error.type, VerificationErrorType.unknown);
        expect(failed.error.message, isNotEmpty);
      },
    );
  });

  group('transaction callbacks', () {
    test('onTransactionUpdated is delivered only to its own call id', () async {
      DiditTransactionResult? updated;
      await DiditSdk.submitTransaction(
        'token',
        const DiditTransactionPayload(txnId: 'txn-1'),
        options: DiditTransactionOptions(
          onTransactionUpdated: (result) => updated = result,
        ),
      );

      final callId = platform.transactionOptions?['callId'] as String;

      platform.transactionUpdateHandler?.call('other-call', <String, dynamic>{
        'transactionId': 'txn-other',
      });
      expect(updated, isNull);

      platform.transactionUpdateHandler?.call(callId, <String, dynamic>{
        'transactionId': 'txn-1',
        'status': 'APPROVED',
      });
      expect(updated?.transactionId, 'txn-1');
      expect(updated?.status, 'APPROVED');

      platform.transactionUpdateHandler?.call(callId, <String, dynamic>{
        'transactionId': 'txn-1',
        'status': 'DECLINED',
      });
      expect(updated?.status, 'APPROVED');
    });

    test(
      'the transaction payload, base URL and auto-launch flag are forwarded',
      () async {
        await DiditSdk.submitTransaction(
          'token',
          const DiditTransactionPayload(
            txnId: 'txn-2',
            type: 'crypto',
            includeCryptoScreening: true,
          ),
          options: const DiditTransactionOptions(
            baseUrl: 'https://staging.example',
            autoLaunchAction: false,
          ),
        );

        expect(platform.transactionPayload?['txnId'], 'txn-2');
        expect(platform.transactionPayload?['type'], 'crypto');
        expect(platform.transactionPayload?['includeCryptoScreening'], true);
        expect(
          platform.transactionOptions?['baseUrl'],
          'https://staging.example',
        );
        expect(platform.transactionOptions?['autoLaunchAction'], false);
      },
    );

    test('getTransaction forwards the base URL override', () async {
      await DiditSdk.getTransaction(
        'token',
        'txn-3',
        options: const DiditTransactionOptions(
          baseUrl: 'https://staging.example',
        ),
      );

      expect(
        platform.getTransactionOptions?['baseUrl'],
        'https://staging.example',
      );
    });
  });
}
