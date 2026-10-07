import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// The example app's iOS location setup. The native Location step reads these
// keys, and iOS looks the precise-location string up by its purpose key.
void main() {
  const purposeKey = 'DiditLocationVerification';
  final plist = File('example/ios/Runner/Info.plist').readAsStringSync();
  final spanish = File(
    'example/ios/Runner/es.lproj/InfoPlist.strings',
  ).readAsStringSync();
  final project = File(
    'example/ios/Runner.xcodeproj/project.pbxproj',
  ).readAsStringSync();

  String? plistString(String key) => RegExp(
    '<key>${RegExp.escape(key)}</key>\\s*<string>([^<]*)</string>',
  ).firstMatch(plist)?.group(1);

  String? spanishString(String key) => RegExp(
    '^"${RegExp.escape(key)}" = "([^"]*)";\$',
    multiLine: true,
  ).firstMatch(spanish)?.group(1);

  test('Info.plist declares the When In Use location string', () {
    expect(
      plistString('NSLocationWhenInUseUsageDescription'),
      'Your location is used to confirm where you are for this verification.',
    );
  });

  test('Info.plist declares the precise-location purpose key', () {
    final dictionary = RegExp(
      '<key>NSLocationTemporaryUsageDescriptionDictionary</key>\\s*<dict>(.*?)</dict>',
      dotAll: true,
    ).firstMatch(plist)?.group(1);

    expect(dictionary, isNotNull);
    expect(
      RegExp(
        '<key>$purposeKey</key>\\s*<string>([^<]*)</string>',
      ).firstMatch(dictionary!)?.group(1),
      'This verification needs your precise location once.',
    );
  });

  test('es.lproj/InfoPlist.strings translates both location strings', () {
    expect(
      spanishString('NSLocationWhenInUseUsageDescription'),
      'Tu ubicación se usa para confirmar dónde estás en esta verificación.',
    );
    expect(
      spanishString(purposeKey),
      'Esta verificación necesita tu ubicación precisa una vez.',
    );
  });

  test('the Xcode project bundles the Spanish InfoPlist.strings', () {
    expect(project, contains('path = es.lproj/InfoPlist.strings;'));
    expect(
      RegExp(
        r'/\* Resources \*/ = \{\s*isa = PBXResourcesBuildPhase;[^}]*InfoPlist\.strings in Resources',
      ).hasMatch(project),
      isTrue,
    );
    expect(RegExp(r'knownRegions = \([^)]*\bes,').hasMatch(project), isTrue);
  });
}
