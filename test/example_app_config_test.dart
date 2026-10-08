import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// The example app's iOS location setup. The native Location step reads these
// keys, and iOS looks the precise-location string up by its purpose key.
void main() {
  const whenInUseKey = 'NSLocationWhenInUseUsageDescription';
  const purposeKey = 'DiditLocationVerification';
  final plist = File('example/ios/Runner/Info.plist').readAsStringSync();

  String? plistString(String source, String key) => RegExp(
    '<key>${RegExp.escape(key)}</key>\\s*<string>([^<]+)</string>',
  ).firstMatch(source)?.group(1);

  test('Info.plist declares the When In Use location string', () {
    expect(plistString(plist, whenInUseKey), isNotNull);
  });

  test('Info.plist declares the precise-location purpose key', () {
    final dictionary = RegExp(
      '<key>NSLocationTemporaryUsageDescriptionDictionary</key>\\s*<dict>(.*?)</dict>',
      dotAll: true,
    ).firstMatch(plist)?.group(1);

    expect(dictionary, isNotNull);
    expect(plistString(dictionary!, purposeKey), isNotNull);
  });

  test('es.lproj/InfoPlist.strings translates both location strings', () {
    final spanish = File(
      'example/ios/Runner/es.lproj/InfoPlist.strings',
    ).readAsStringSync();

    for (final key in [whenInUseKey, purposeKey]) {
      expect(spanish, matches(RegExp('^"$key" = "[^"]+";\$', multiLine: true)));
    }
  });

  test('the Xcode project bundles the Spanish InfoPlist.strings', () {
    final project = File(
      'example/ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();

    expect(project, contains('path = es.lproj/InfoPlist.strings;'));
    expect(project, contains('InfoPlist.strings in Resources'));
  });
}
