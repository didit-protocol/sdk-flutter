import 'package:flutter_test/flutter_test.dart';
import 'package:didit_sdk/sdk_flutter.dart';
import 'package:didit_sdk/sdk_flutter_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockSdkFlutterPlatform
    with MockPlatformInterfaceMixin
    implements SdkFlutterPlatform {
  @override
  Future<Map<String, dynamic>> startVerification(
      String token, Map<String, dynamic>? config) async {
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
    String? metadata,
    Map<String, dynamic>? contactDetails,
    Map<String, dynamic>? expectedDetails,
    Map<String, dynamic>? config,
  ) async {
    return {
      'type': 'completed',
      'sessionId': 'test-workflow-session-id',
      'status': 'Pending',
    };
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
}
