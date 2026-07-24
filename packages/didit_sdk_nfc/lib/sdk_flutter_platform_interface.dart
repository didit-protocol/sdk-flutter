import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'sdk_flutter_method_channel.dart';

abstract class SdkFlutterPlatform extends PlatformInterface {
  SdkFlutterPlatform() : super(token: _token);

  static final Object _token = Object();

  static SdkFlutterPlatform _instance = MethodChannelSdkFlutter();

  static SdkFlutterPlatform get instance => _instance;

  static set instance(SdkFlutterPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Start verification with an existing session token.
  Future<Map<String, dynamic>> startVerification(
    String token,
    Map<String, dynamic>? config,
  ) {
    throw UnimplementedError('startVerification() has not been implemented.');
  }

  /// Start verification by creating a session with a workflow ID.
  Future<Map<String, dynamic>> startVerificationWithWorkflow(
    String workflowId,
    String? vendorData,
    Map<String, dynamic>? config,
  ) {
    throw UnimplementedError(
        'startVerificationWithWorkflow() has not been implemented.');
  }

  /// Submit a transaction with a transaction SDK token.
  Future<Map<String, dynamic>> submitTransaction(
    String transactionToken,
    Map<String, dynamic> transaction,
    Map<String, dynamic> options,
  ) {
    throw UnimplementedError('submitTransaction() has not been implemented.');
  }

  /// Fetch a transaction previously submitted with the same token.
  Future<Map<String, dynamic>> getTransaction(
    String transactionToken,
    String transactionId,
    Map<String, dynamic> options,
  ) {
    throw UnimplementedError('getTransaction() has not been implemented.');
  }

  /// Register the handler invoked when the platform reports a refreshed
  /// transaction after an auto-launched action completes.
  void setTransactionUpdateHandler(
    void Function(String callId, Map<String, dynamic> result)? handler,
  ) {
    throw UnimplementedError(
        'setTransactionUpdateHandler() has not been implemented.');
  }
}
