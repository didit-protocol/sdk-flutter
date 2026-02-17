import 'package:flutter_test/flutter_test.dart';
import 'package:sdk_flutter/sdk_flutter.dart';
import 'package:sdk_flutter/sdk_flutter_platform_interface.dart';
import 'package:sdk_flutter/sdk_flutter_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockSdkFlutterPlatform
    with MockPlatformInterfaceMixin
    implements SdkFlutterPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final SdkFlutterPlatform initialPlatform = SdkFlutterPlatform.instance;

  test('$MethodChannelSdkFlutter is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelSdkFlutter>());
  });

  test('getPlatformVersion', () async {
    SdkFlutter sdkFlutterPlugin = SdkFlutter();
    MockSdkFlutterPlatform fakePlatform = MockSdkFlutterPlatform();
    SdkFlutterPlatform.instance = fakePlatform;

    expect(await sdkFlutterPlugin.getPlatformVersion(), '42');
  });
}
