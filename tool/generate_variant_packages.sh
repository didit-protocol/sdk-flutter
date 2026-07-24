#!/usr/bin/env bash
# Regenerates the standalone variant packages (didit_sdk_core,
# didit_sdk_autodetection, didit_sdk_nfc) from the canonical didit_sdk plugin
# at the repo root. Each variant package is a full copy of the plugin (Dart +
# Android + iOS) pinned to one native SDK variant on BOTH platforms, so exactly
# one plugin ever sits in a consumer's dependency graph (Flutter cannot express
# per-app native variant selection inside a single package under Swift Package
# Manager). Run from the repo root after ANY change to lib/, android/,
# ios/didit_sdk/Sources, the version, or the native SDK pins - the variants
# must never drift. CHANGELOG.md files are left untouched when they exist -
# update those by hand per release. See README "Native SDK Variants".
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION=$(sed -n 's/^version: //p' pubspec.yaml)
NATIVE_IOS_VERSION=$(sed -n 's/.*exact: "\(.*\)").*/\1/p' ios/didit_sdk/Package.swift)
[[ -n "$VERSION" && -n "$NATIVE_IOS_VERSION" ]] || { echo "failed to read versions" >&2; exit 1; }
echo "wrapper $VERSION / native iOS DiditSDK $NATIVE_IOS_VERSION"

generate() {
  local name=$1 variant=$2 product=$3 subspec=$4 floor=$5 feature_desc=$6 auto=$7 nfc=$8
  local pkg=packages/$name
  echo "generating $pkg"

  rm -rf "$pkg/ios" "$pkg/lib" "$pkg/android"
  mkdir -p "$pkg/ios/$name"

  cp LICENSE "$pkg/LICENSE"
  cp -R lib "$pkg/lib"
  cp -R android "$pkg/android"
  cp -R ios/didit_sdk/Sources "$pkg/ios/$name/Sources"
  mv "$pkg/ios/$name/Sources/didit_sdk" "$pkg/ios/$name/Sources/$name"

  # Pin the Android default variant (still overridable via the
  # diditSdkAndroidVariant gradle property, matching the main package).
  sed -i '' "s/?: \"all\"/?: \"$variant\"/" "$pkg/android/build.gradle.kts"
  grep -q "?: \"$variant\"" "$pkg/android/build.gradle.kts" || { echo "android default pin failed for $name" >&2; exit 1; }

  cat > "$pkg/pubspec.yaml" <<EOF
name: $name
description: Didit Identity Verification SDK for Flutter, pinned to the $variant native SDK variant ($feature_desc). Same Dart API as didit_sdk - depend on exactly one of the didit_sdk packages. Generated from didit_sdk - do not edit by hand.
version: $VERSION
homepage: https://didit.me
repository: https://github.com/didit-protocol/sdk-flutter
issue_tracker: https://github.com/didit-protocol/sdk-flutter/issues

environment:
  sdk: ^3.11.0
  flutter: '>=3.3.0'

dependencies:
  flutter:
    sdk: flutter
  plugin_platform_interface: ^2.0.2

dev_dependencies:
  flutter_lints: ^6.0.0

flutter:
  plugin:
    platforms:
      android:
        package: me.didit.sdk.sdk_flutter
        pluginClass: SdkFlutterPlugin
      ios:
        pluginClass: SdkFlutterPlugin
EOF

  cat > "$pkg/ios/.gitignore" <<EOF
# SwiftPM build artifact (generated when the plugin package is resolved locally)
$name/Package.resolved
.build/
EOF

  cat > "$pkg/ios/$name.podspec" <<EOF
Pod::Spec.new do |s|
  s.name             = '$name'
  s.version          = '$VERSION'
  s.summary          = 'Didit Identity Verification SDK for Flutter - $variant variant'
  s.description      = <<-DESC
Didit identity verification Flutter plugin pinned to the $subspec native SDK
variant ($feature_desc). Generated from didit_sdk.
                       DESC
  s.homepage         = 'https://github.com/didit-protocol/sdk-flutter'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Didit' => 'support@didit.me' }
  s.source           = { :path => '.' }
  s.source_files = '$name/Sources/$name/**/*.swift'
  s.resource_bundles = { '${name}_privacy' => ['$name/Sources/$name/Resources/PrivacyInfo.xcprivacy'] }
  s.dependency 'Flutter'

  # Fixed native variant - unlike didit_sdk this podspec intentionally ignores
  # \$DiditSdkIosVariant. Keep your Podfile's DiditSDK subspec line in sync
  # ($subspec) when building with CocoaPods.
  s.dependency '$subspec', '$NATIVE_IOS_VERSION'

  s.platform = :ios, '$floor'
  s.static_framework = true
  s.swift_version = '5.0'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
end
EOF

  local dashed=${name//_/-}
  cat > "$pkg/ios/$name/Package.swift" <<EOF
// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "$name",
    platforms: [
        .iOS("$floor")
    ],
    products: [
        .library(name: "$dashed", targets: ["$name"])
    ],
    dependencies: [
        .package(url: "https://github.com/didit-protocol/sdk-ios.git", exact: "$NATIVE_IOS_VERSION")
    ],
    targets: [
        .target(
            name: "$name",
            dependencies: [
                .product(name: "$product", package: "sdk-ios")
            ],
            resources: [
                .process("Resources")
            ]
        )
    ]
)
EOF

  cat > "$pkg/README.md" <<EOF
# $name

The Didit Identity Verification SDK for Flutter, pinned to the **$variant** native SDK variant on both iOS and Android: $feature_desc.

| | |
|---|---|
| Automatic capture | $auto |
| NFC passport reading | $nfc |
| Minimum iOS | $floor |

It exposes exactly the same Dart API as [\`didit_sdk\`](https://pub.dev/packages/didit_sdk) - only the bundled native SDK differs.
Depend on exactly one of the \`didit_sdk\` packages:

\`\`\`yaml
dependencies:
  $name: ^$VERSION
\`\`\`

\`\`\`dart
import 'package:$name/sdk_flutter.dart';
\`\`\`

See the [\`didit_sdk\` README](https://pub.dev/packages/didit_sdk) for full setup and usage documentation - substitute \`didit_sdk\` with \`$name\` in import statements.
This package is generated from \`didit_sdk\` - do not edit it by hand.
EOF

  if [[ ! -f "$pkg/CHANGELOG.md" ]]; then
    cat > "$pkg/CHANGELOG.md" <<EOF
## $VERSION

* Initial release: the didit_sdk Flutter plugin pinned to the $variant native SDK variant on both platforms ($feature_desc; minimum iOS $floor). Supports both Swift Package Manager and CocoaPods on iOS.
EOF
  fi
}

#        name                      variant        SPM product           pod subspec              floor   description                                                    auto  nfc
generate didit_sdk_core            core           DiditSDKCore          DiditSDK/Core            13.0    "smallest, manual capture only - no automatic capture, no NFC" No    No
generate didit_sdk_autodetection   autodetection  DiditSDKAutoDetection DiditSDK/AutoDetection   13.0    "automatic capture without NFC"                                Yes   No
generate didit_sdk_nfc             nfc            DiditSDKNFC           DiditSDK/NFC             15.0    "NFC passport reading without automatic capture"               No    Yes

echo "done"
