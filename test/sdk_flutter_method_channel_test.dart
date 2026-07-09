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

  test('submitTransaction calls platform channel with payload', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          expect(methodCall.method, 'submitTransaction');
          expect(methodCall.arguments, {
            'transactionToken': 'txn-token',
            'transaction': {'txnId': 'txn-1', 'type': 'crypto'},
            'options': {'callId': 'call-1', 'autoLaunchAction': true},
          });
          return <String, dynamic>{
            'transactionId': 'created-id',
            'status': 'CREATED',
          };
        });

    final result = await platform.submitTransaction(
      'txn-token',
      {'txnId': 'txn-1', 'type': 'crypto'},
      {'callId': 'call-1', 'autoLaunchAction': true},
    );

    expect(result['transactionId'], 'created-id');
    expect(result['status'], 'CREATED');
  });

  test('getTransaction calls platform channel', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          expect(methodCall.method, 'getTransaction');
          expect(methodCall.arguments, {
            'transactionToken': 'txn-token',
            'transactionId': 'txn-1',
            'options': <String, dynamic>{},
          });
          return <String, dynamic>{
            'transactionId': 'txn-1',
            'status': 'APPROVED',
          };
        });

    final result = await platform.getTransaction('txn-token', 'txn-1', {});

    expect(result['transactionId'], 'txn-1');
    expect(result['status'], 'APPROVED');
  });

  test('onTransactionUpdated platform call reaches the handler', () async {
    String? receivedCallId;
    Map<String, dynamic>? receivedResult;
    platform.setTransactionUpdateHandler((callId, result) {
      receivedCallId = callId;
      receivedResult = result;
    });

    const codec = StandardMethodCodec();
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      'didit_sdk',
      codec.encodeMethodCall(
        const MethodCall('onTransactionUpdated', {
          'callId': 'call-9',
          'result': {'transactionId': 'txn-9', 'status': 'APPROVED'},
        }),
      ),
      (data) {},
    );

    expect(receivedCallId, 'call-9');
    expect(receivedResult?['transactionId'], 'txn-9');
    expect(receivedResult?['status'], 'APPROVED');

    platform.setTransactionUpdateHandler(null);
  });
}
