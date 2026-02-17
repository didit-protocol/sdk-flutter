import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'sdk_flutter_platform_interface.dart';

/// An implementation of [SdkFlutterPlatform] that uses method channels.
class MethodChannelSdkFlutter extends SdkFlutterPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('sdk_flutter');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }
}
