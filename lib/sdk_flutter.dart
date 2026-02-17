
import 'sdk_flutter_platform_interface.dart';

class SdkFlutter {
  Future<String?> getPlatformVersion() {
    return SdkFlutterPlatform.instance.getPlatformVersion();
  }
}
