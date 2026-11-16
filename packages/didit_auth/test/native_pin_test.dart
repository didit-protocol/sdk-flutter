import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The native release is pinned in the Android build, the iOS podspec and the
/// Swift package manifest. They must name the same release.
void main() {
  String read(String path) => File(path).readAsStringSync();

  test('Android, CocoaPods and Swift Package Manager pin one release', () {
    final android = RegExp(
      r'val diditAuthNativeVersion = "([^"]+)"',
    ).firstMatch(read('android/build.gradle.kts'))?.group(1);
    final podspec = RegExp(
      r"didit_auth_native_version = '([^']+)'",
    ).firstMatch(read('ios/didit_auth.podspec'))?.group(1);
    final swiftPackage = RegExp(
      r'exact: "([^"]+)"',
    ).firstMatch(read('ios/didit_auth/Package.swift'))?.group(1);

    expect(android, isNotNull);
    expect(podspec, android);
    expect(swiftPackage, android);
  });

  test('the README names the pinned release', () {
    final pin = RegExp(
      r'val diditAuthNativeVersion = "([^"]+)"',
    ).firstMatch(read('android/build.gradle.kts'))!.group(1);

    expect(read('README.md'), contains('sdk-ios/$pin/DiditSDK.podspec'));
  });
}
