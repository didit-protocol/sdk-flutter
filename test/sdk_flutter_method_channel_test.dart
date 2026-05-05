import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:didit_sdk/sdk_flutter_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final platform = MethodChannelSdkFlutter();
  const channel = MethodChannel('didit_sdk');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          expect(methodCall.method, 'startVerification');
          expect(methodCall.arguments, {'token': 'test-token'});
          return <String, dynamic>{
            'type': 'completed',
            'sessionId': 'test-session-id',
            'status': 'Approved',
          };
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('startVerification returns result map', () async {
    final result = await platform.startVerification('test-token', null);
    expect(result['type'], 'completed');
    expect(result['sessionId'], 'test-session-id');
  });

  test('startVerificationWithWorkflow calls platform channel', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          expect(methodCall.method, 'startVerificationWithWorkflow');
          expect(methodCall.arguments, {
            'workflowId': 'test-workflow',
            'vendorData': 'test-vendor',
          });
          return <String, dynamic>{
            'type': 'completed',
            'sessionId': 'test-workflow-session-id',
            'status': 'Pending',
          };
        });

    final result = await platform.startVerificationWithWorkflow(
      'test-workflow',
      'test-vendor',
      null,
    );

    expect(result['type'], 'completed');
    expect(result['sessionId'], 'test-workflow-session-id');
  });
}
