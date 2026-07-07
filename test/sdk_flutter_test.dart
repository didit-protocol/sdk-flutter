import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:didit_sdk/sdk_flutter.dart';
import 'package:didit_sdk/sdk_flutter_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockSdkFlutterPlatform
    with MockPlatformInterfaceMixin
    implements SdkFlutterPlatform {
  void Function(String callId, Map<String, dynamic> result)?
      transactionUpdateHandler;
  Map<String, dynamic>? lastTransactionOptions;
  bool throwValidationError = false;

  @override
  Future<Map<String, dynamic>> startVerification(
    String token,
    Map<String, dynamic>? config,
  ) async {
    return {
      'type': 'completed',
      'sessionId': 'test-session-id',
      'status': 'Approved',
    };
  }

  @override
  Future<Map<String, dynamic>> startVerificationWithWorkflow(
    String workflowId,
    String? vendorData,
    Map<String, dynamic>? config,
  ) async {
    return {
      'type': 'completed',
      'sessionId': 'test-workflow-session-id',
      'status': 'Pending',
    };
  }

  @override
  Future<Map<String, dynamic>> submitTransaction(
    String transactionToken,
    Map<String, dynamic> transaction,
    Map<String, dynamic> options,
  ) async {
    lastTransactionOptions = options;
    if (throwValidationError) {
      throw PlatformException(
        code: 'validation',
        message: 'txnId is required',
        details: {
          'txnId': ['This field is required.'],
        },
      );
    }
    return {
      'transactionId': 'test-transaction-id',
      'status': 'AWAITING_USER',
      'travelRuleStatus': 'PENDING',
      'actionRequired': {
        'type': 'wallet_ownership',
        'url': 'https://verify.example/wallet-ownership/token',
        'widgetSessionId': 'widget-session-id',
        'expiresAt': '2026-07-08T00:00:00Z',
      },
    };
  }

  @override
  Future<Map<String, dynamic>> getTransaction(
    String transactionToken,
    String transactionId,
    Map<String, dynamic> options,
  ) async {
    return {'transactionId': transactionId, 'status': 'APPROVED'};
  }

  @override
  void setTransactionUpdateHandler(
    void Function(String callId, Map<String, dynamic> result)? handler,
  ) {
    transactionUpdateHandler = handler;
  }
}

void main() {
  final platform = MockSdkFlutterPlatform();

  setUp(() {
    SdkFlutterPlatform.instance = platform;
  });

  test('startVerification returns completed result', () async {
    final result = await DiditSdk.startVerification('test-token');

    expect(result, isA<VerificationCompleted>());
    final completed = result as VerificationCompleted;
    expect(completed.session.sessionId, 'test-session-id');
    expect(completed.session.status, VerificationStatus.approved);
  });

  test('startVerificationWithWorkflow returns completed result', () async {
    final result = await DiditSdk.startVerificationWithWorkflow(
      'test-workflow',
      vendorData: 'user-123',
    );

    expect(result, isA<VerificationCompleted>());
    final completed = result as VerificationCompleted;
    expect(completed.session.sessionId, 'test-workflow-session-id');
    expect(completed.session.status, VerificationStatus.pending);
  });

  test('VerificationResult.fromMap handles failed result', () {
    final result = VerificationResult.fromMap({
      'type': 'failed',
      'errorType': 'sessionExpired',
      'errorMessage': 'The session has expired.',
    });

    expect(result, isA<VerificationFailed>());
    final failed = result as VerificationFailed;
    expect(failed.error.type, VerificationErrorType.sessionExpired);
    expect(failed.error.message, 'The session has expired.');
  });

  test('VerificationResult.fromMap handles cancelled result', () {
    final result = VerificationResult.fromMap({
      'type': 'cancelled',
      'sessionId': 'cancelled-session',
      'status': 'Pending',
    });

    expect(result, isA<VerificationCancelled>());
    final cancelled = result as VerificationCancelled;
    expect(cancelled.session?.sessionId, 'cancelled-session');
  });

  test('submitTransaction returns typed result with actionRequired', () async {
    platform.throwValidationError = false;

    final result = await DiditSdk.submitTransaction(
      'test-token',
      const DiditTransactionPayload(txnId: 'txn-1'),
    );

    expect(result.transactionId, 'test-transaction-id');
    expect(result.status, 'AWAITING_USER');
    expect(result.travelRuleStatus, 'PENDING');
    expect(
      result.actionRequired?.type,
      DiditTransactionActionRequired.typeWalletOwnership,
    );
    expect(result.actionRequired?.widgetSessionId, 'widget-session-id');
    expect(platform.lastTransactionOptions?['autoLaunchAction'], true);
    expect(platform.lastTransactionOptions?['callId'], isNotEmpty);
  });

  test('submitTransaction delivers onTransactionUpdated by callId', () async {
    platform.throwValidationError = false;
    DiditTransactionResult? updated;

    await DiditSdk.submitTransaction(
      'test-token',
      const DiditTransactionPayload(txnId: 'txn-2'),
      options: DiditTransactionOptions(
        onTransactionUpdated: (result) => updated = result,
      ),
    );

    final callId = platform.lastTransactionOptions?['callId'] as String;
    platform.transactionUpdateHandler?.call(callId, {
      'transactionId': 'test-transaction-id',
      'status': 'APPROVED',
    });

    expect(updated?.transactionId, 'test-transaction-id');
    expect(updated?.status, 'APPROVED');
  });

  test('submitTransaction maps validation errors with fieldErrors', () async {
    platform.throwValidationError = true;

    try {
      await DiditSdk.submitTransaction(
        'test-token',
        const DiditTransactionPayload(txnId: ''),
      );
      fail('Expected DiditTransactionException');
    } on DiditTransactionException catch (e) {
      expect(e.code, DiditTransactionException.codeValidation);
      expect(e.message, 'txnId is required');
      expect(e.fieldErrors?['txnId'], ['This field is required.']);
    } finally {
      platform.throwValidationError = false;
    }
  });

  test('getTransaction returns typed result', () async {
    final result = await DiditSdk.getTransaction('test-token', 'txn-3');

    expect(result.transactionId, 'txn-3');
    expect(result.status, 'APPROVED');
    expect(result.actionRequired, isNull);
  });
}
