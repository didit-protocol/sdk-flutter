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
    String? metadata,
    Map<String, dynamic>? contactDetails,
    Map<String, dynamic>? expectedDetails,
    Map<String, dynamic>? config,
  ) {
    throw UnimplementedError(
        'startVerificationWithWorkflow() has not been implemented.');
  }
}
