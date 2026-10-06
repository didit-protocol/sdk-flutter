import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// The Location step runs in the native SDKs, but the permission entries it
// needs belong to the host app. The example app must keep them so it can run
// a workflow with a Location step on both platforms.
void main() {
  test('example iOS app explains why it asks for the location', () {
    final plist = File('example/ios/Runner/Info.plist').readAsStringSync();
    final usage = RegExp(
      r'<key>NSLocationWhenInUseUsageDescription</key>\s*<string>([^<]*)</string>',
    ).firstMatch(plist);

    expect(usage, isNotNull);
    expect(
      usage!.group(1),
      'Your location is used to confirm where you are for this verification.',
    );
  });

  test('example Android app declares precise and approximate location', () {
    final manifest = File(
      'example/android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final permissions = RegExp(
      r'<uses-permission\s+android:name="([^"]+)"',
    ).allMatches(manifest).map((match) => match.group(1)).toSet();

    expect(
      permissions,
      containsAll(<String>[
        'android.permission.ACCESS_FINE_LOCATION',
        'android.permission.ACCESS_COARSE_LOCATION',
      ]),
    );
  });
}
