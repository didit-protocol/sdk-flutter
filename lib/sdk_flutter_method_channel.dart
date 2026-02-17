import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'sdk_flutter_platform_interface.dart';

/// MethodChannel implementation of [SdkFlutterPlatform].
class MethodChannelSdkFlutter extends SdkFlutterPlatform {
  @visibleForTesting
  final methodChannel = const MethodChannel('didit_sdk');

  @override
  Future<Map<String, dynamic>> startVerification(
    String token,
    Map<String, dynamic>? config,
  ) async {
    final result = await methodChannel.invokeMethod<Map>('startVerification', {
      'token': token,
      if (config != null) 'config': config,
    });
    return Map<String, dynamic>.from(result ?? {});
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
    final result = await methodChannel
        .invokeMethod<Map>('startVerificationWithWorkflow', {
      'workflowId': workflowId,
      if (vendorData != null) 'vendorData': vendorData,
      if (metadata != null) 'metadata': metadata,
      if (contactDetails != null) 'contactDetails': contactDetails,
      if (expectedDetails != null) 'expectedDetails': expectedDetails,
      if (config != null) 'config': config,
    });
    return Map<String, dynamic>.from(result ?? {});
  }
}
