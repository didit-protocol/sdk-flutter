# DiditSDK for Flutter

A Flutter plugin for Didit Identity Verification. Wraps the native iOS and Android SDKs with a unified Dart API for document scanning, NFC passport reading, face verification, and liveness detection.

## Requirements

| Requirement | Minimum Version |
|-------------|----------------|
| Flutter | 3.3+ |
| Dart | 3.11+ |
| iOS | 13.0+ (NFC requires iOS 15.0+) |
| Android | API 23+ (6.0 Marshmallow) |

## Installation

Add the dependency to your `pubspec.yaml`:

```yaml
dependencies:
  didit_sdk: ^4.0.4
```

Then run:

```bash
flutter pub get
```

### Native SDK Variants

The Flutter plugin can install the same native SDK variants exposed by the iOS and Android SDKs:

| Variant | Automatic capture | NFC passport reading | Use when |
|---------|-------------------|----------------------|----------|
| `all` | Yes | Yes | You want the complete SDK (default) |
| `core` | No | No | You only need manual capture and the smallest binary |
| `autodetection` | Yes | No | You need automatic capture without NFC |
| `nfc` | No | Yes | You need NFC passport reading without automatic capture |

### iOS Setup

The Flutter plugin picks the native iOS SDK variant from `$DiditSdkIosVariant`, a Ruby global you set in your app's `ios/Podfile`. The plugin's `didit_sdk.podspec` reads the same global, so the choice is consistent and — critically — it survives every implicit `pod install` that `flutter build` triggers. Configure your `ios/Podfile` like this:

```ruby
# Pick one: 'all', 'core', 'autodetection', 'nfc'
$DiditSdkIosVariant = 'all'

didit_sdk_ios_deployment_target = ['all', 'nfc'].include?($DiditSdkIosVariant) ? '15.0' : '13.0'
platform :ios, didit_sdk_ios_deployment_target

didit_sdk_ios_pod = case $DiditSdkIosVariant
                    when 'all'
                      'DiditSDK/All'
                    when 'core'
                      'DiditSDK/Core'
                    when 'autodetection'
                      'DiditSDK/AutoDetection'
                    when 'nfc'
                      'DiditSDK/NFC'
                    else
                      raise "Invalid $DiditSdkIosVariant '#{$DiditSdkIosVariant}'. Supported values: all, core, autodetection, nfc."
                    end
didit_sdk_ios_podspec = 'https://raw.githubusercontent.com/didit-protocol/sdk-ios/4.0.4/DiditSDK.podspec'

target 'Runner' do
  use_frameworks!

  pod didit_sdk_ios_pod, :podspec => didit_sdk_ios_podspec

  flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = didit_sdk_ios_deployment_target
    end
  end
end
```

The default variant is `all`. Variants `all` and `nfc` require an iOS 15.0+ deployment target. Variants `core` and `autodetection` can target iOS 13.0+.

To change variant, edit the `$DiditSdkIosVariant` line, then refresh CocoaPods so the previous variant's binaries are not reused:

```bash
cd ios
rm -rf Pods Podfile.lock
pod install
```

`$DiditSdkIosVariant` is the only mechanism that reliably survives `flutter build` / `flutter run`. The plugin also accepts a `DIDIT_SDK_IOS_VARIANT` environment variable as a CI fallback, but env vars set inline in a shell command (`DIDIT_SDK_IOS_VARIANT=nfc flutter build ...`) are typically lost the next time Flutter spawns CocoaPods. Prefer the Podfile global.

### Android Setup

The Flutter plugin selects the native Android SDK variant from `diditSdkAndroidVariant`. The default variant is `all`. To choose another variant, add this to `android/gradle.properties`:

```properties
diditSdkAndroidVariant=autodetection
```

Supported values are `all`, `core`, `autodetection`, and `nfc`.

If you use `all` or `nfc`, add the following packaging rule to your `android/app/build.gradle.kts` inside the `android` block:

```kotlin
android {
    packaging {
        resources {
            pickFirsts += "META-INF/versions/9/OSGI-INF/MANIFEST.MF"
        }
    }
}
```

This resolves a duplicate metadata file shipped by the SDK's cryptography dependencies (BouncyCastle). Without it the build will fail with a `mergeDebugJavaResource` error. This rule is not needed for `core` or `autodetection`.

## Permissions

### iOS

Add the following keys to your app's `Info.plist`:

| Permission | Info.plist Key | Description | Required |
|------------|----------------|-------------|----------|
| Camera | `NSCameraUsageDescription` | Document scanning and face verification | Yes |
| Microphone | `NSMicrophoneUsageDescription` | Video recording for liveness checks | Yes |
| Photo Library | `NSPhotoLibraryUsageDescription` | Upload documents from device gallery | Yes |
| NFC | `NFCReaderUsageDescription` | Read NFC chips in passports/ID cards | If using NFC |

```xml
<key>NSCameraUsageDescription</key>
<string>Camera access is required for identity verification.</string>
<key>NSMicrophoneUsageDescription</key>
<string>Microphone access is required for liveness verification.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Photo library access is required to upload documents.</string>
<key>NFCReaderUsageDescription</key>
<string>NFC is used to read passport chip data for identity verification.</string>
```

If any required iOS privacy key is missing, iOS terminates the app as soon as the SDK tries to access that protected resource. For example, missing `NSCameraUsageDescription` causes a crash when the user taps the document camera's take photo button.

#### NFC Configuration (for passport/ID chip reading)

1. **Add NFC Capability** in Xcode:
   - Select your target > Signing & Capabilities > + Capability > Near Field Communication Tag Reading

2. **Add ISO7816 Identifiers** to `Info.plist`:
   ```xml
   <key>com.apple.developer.nfc.readersession.iso7816.select-identifiers</key>
   <array>
       <string>D23300000045737445494420763335</string>
       <string>A0000002471001</string>
       <string>A0000002472001</string>
       <string>00000000000000</string>
   </array>
   ```

3. **Add an entitlements file** with NFC tag reading enabled:
   ```xml
   <key>com.apple.developer.nfc.readersession.formats</key>
   <array>
       <string>TAG</string>
   </array>
   ```

Make sure the app's provisioning profile includes the NFC Tag Reading capability. If the bundle ID is not configured for NFC in your Apple Developer account, Xcode will fail signing with a missing `com.apple.developer.nfc.readersession.formats` entitlement.

This NFC configuration is not needed when `$DiditSdkIosVariant` is `'core'` or `'autodetection'`.

### Android

The following permissions are declared in the native SDK's `AndroidManifest.xml` and merged automatically:

| Permission | Description | Required |
|------------|-------------|----------|
| `INTERNET` | Network access for API communication | Yes |
| `ACCESS_NETWORK_STATE` | Detect network availability | Yes |
| `CAMERA` | Document scanning and face verification | Yes |
| `NFC` | Read NFC chips in passports/ID cards | If using NFC |

Camera and NFC hardware features are declared as optional (`android:required="false"`), so your app can be installed on devices without these features. When `diditSdkAndroidNfcEnabled=false`, the Android NFC permission and feature are not added by the SDK.

#### Runtime Permissions

The SDK handles Android runtime permission requests automatically. When the user reaches a step that requires camera access:

1. The SDK prompts for camera permission if not already granted
2. If the user **denies** the permission, an error message is displayed with a "Try Again" button
3. If the user **grants** the permission, the verification flow continues

You do not need to request camera permission in your app code before calling `startVerification()` — the SDK manages this internally.

## Quick Start

```dart
import 'package:didit_sdk/sdk_flutter.dart';

final result = await DiditSdk.startVerification('your-session-token');

switch (result) {
  case VerificationCompleted(:final session):
    print('Status: ${session.status}');
    print('Session ID: ${session.sessionId}');
  case VerificationCancelled():
    print('User cancelled');
  case VerificationFailed(:final error):
    print('Error: ${error.type} - ${error.message}');
}
```

## Integration Methods

The SDK supports two integration methods:

### Method 1: API Integration (Recommended for Production)

Your backend creates a session via the Didit API and returns the session token. This gives you full control over session creation, user tracking, and security.

Read more about how the create session API works here:
https://docs.didit.me/reference/create-session-verification-sessions

```dart
// Your backend creates a session and returns the token
final sessionToken = await yourBackend.createVerificationSession(userId);

// Pass the token to the SDK
final result = await DiditSdk.startVerification(sessionToken);
```

This approach gives you full control over:

- Associating sessions with your users (`vendor_data`)
- Setting contact details, expected details, and metadata
- Configuring callbacks per session

### Method 2: Unilink Integration (Simpler)

For simpler integrations, the SDK can create sessions directly using your workflow ID — no backend needed:

```dart
final result = await DiditSdk.startVerificationWithWorkflow(
  'your-workflow-id',
  vendorData: 'user-123',
  config: DiditConfig(loggingEnabled: true),
);
```

> **Note:** Advanced session parameters (`contact_details`, `expected_details`, `metadata`) are only available through the API Integration method, where your backend calls the [Create Session API](https://docs.didit.me/sessions-api/create-session) directly.

## Configuration

Customize the SDK behavior by passing a `DiditConfig` object:

```dart
final result = await DiditSdk.startVerification(
  'your-session-token',
  config: DiditConfig(
    languageCode: 'es',       // Force Spanish language
    fontFamily: 'Avenir',     // Custom font
    loggingEnabled: true,     // Debug logging
  ),
);
```

### Configuration Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `languageCode` | `String?` | Device locale | ISO 639-1 language code (e.g. `"en"`, `"fr"`, `"ar"`) |
| `fontFamily` | `String?` | System font | Custom font family name |
| `loggingEnabled` | `bool` | `false` | Enable SDK debug logging |
| `showCloseButton` | `bool` | `true` | Show the close (X) button on verification step screens |
| `showExitConfirmation` | `bool` | `true` | Show a confirmation dialog when the user attempts to exit |
| `closeOnComplete` | `bool` | `false` | Auto-dismiss the verification UI when complete |
| `defaultDocumentCamera` | `CameraLens?` | Native default (`back`) | Lens used when first entering the document capture screen |
| `defaultLivenessCamera` | `CameraLens?` | Native default (`front`) | Lens used when first entering the liveness (passive face) capture screen |
| `showDocumentCameraSwitchButton` | `bool` | `true` | Show the in-capture camera switcher on the document screen |
| `showLivenessCameraSwitchButton` | `bool` | `true` | Show the in-capture camera switcher on the liveness screen |

All fields are optional. If no config is provided, the SDK uses sensible defaults matching the native iOS and Android SDKs.

### `languageCode`

Sets the language for the entire verification UI. Pass an ISO 639-1 code (e.g. `"en"`, `"fr"`, `"es"`, `"ar"`). If not set, the SDK automatically detects the device locale and falls back to English.

```dart
// Force French
await DiditSdk.startVerification(token, config: DiditConfig(languageCode: 'fr'));

// Use device locale (default)
await DiditSdk.startVerification(token);
```

### `fontFamily`

Overrides the font used throughout the SDK UI. The font must be registered in your app's native configuration:

- **iOS:** Add the font file to your Xcode project and list it in `Info.plist` under `UIAppFonts`.
- **Android:** Place the font file in `android/app/src/main/res/font/`.

```dart
await DiditSdk.startVerification(token, config: DiditConfig(fontFamily: 'Avenir'));
```

### `loggingEnabled`

Enables verbose debug logging from the native SDK. Useful during development to inspect the SDK's internal state, API calls, and error details. Should be disabled in production.

```dart
await DiditSdk.startVerification(token, config: DiditConfig(loggingEnabled: true));
```

### Language Support

The SDK supports **54 languages**. If no language is specified, the SDK uses the device locale with English as fallback.

#### Supported Languages

| Language | Code | Language | Code |
|----------|------|----------|------|
| Albanian | `sq` | Kazakh | `kk` |
| Arabic | `ar` | Korean | `ko` |
| Armenian | `hy` | Kyrgyz | `ky` |
| Bengali | `bn` | Latvian | `lv` |
| Bosnian | `bs` | Lithuanian | `lt` |
| Bulgarian | `bg` | Macedonian | `mk` |
| Catalan | `ca` | Malay | `ms` |
| Chinese | `zh` | Mongolian | `mn` |
| Chinese (Simplified) | `zh-CN` | Montenegrin | `cnr` |
| Chinese (Traditional) | `zh-TW` | Norwegian | `no` |
| Croatian | `hr` | Persian | `fa` |
| Czech | `cs` | Polish | `pl` |
| Danish | `da` | Portuguese | `pt` |
| Dutch | `nl` | Portuguese (Brazil) | `pt-BR` |
| English | `en` | Romanian | `ro` |
| Estonian | `et` | Russian | `ru` |
| Finnish | `fi` | Serbian | `sr` |
| French | `fr` | Slovak | `sk` |
| Georgian | `ka` | Slovenian | `sl` |
| German | `de` | Somali | `so` |
| Greek | `el` | Spanish | `es` |
| Hebrew | `he` | Swedish | `sv` |
| Hindi | `hi` | Thai | `th` |
| Hungarian | `hu` | Turkish | `tr` |
| Indonesian | `id` | Ukrainian | `uk` |
| Italian | `it` | Uzbek | `uz` |
| Japanese | `ja` | Vietnamese | `vi` |

### Camera Settings

Control which camera lens opens by default on the document and liveness capture screens, and whether the in-capture camera switcher is shown to the user.

```dart
final result = await DiditSdk.startVerification(
  'your-session-token',
  config: DiditConfig(
    defaultDocumentCamera: CameraLens.back,        // back is the default
    defaultLivenessCamera: CameraLens.front,       // front is the default
    showDocumentCameraSwitchButton: true,          // false to lock to the chosen lens
    showLivenessCameraSwitchButton: true,
  ),
);
```

If the requested lens isn't present on the device (for example a tablet with no front camera), the native SDK transparently falls back to the first available camera so capture still works. The in-capture camera switcher is also hidden automatically on devices that expose only one camera, regardless of the `show…SwitchButton` flag.

## Advanced Session Parameters

Parameters like `contact_details`, `expected_details`, and `metadata` are only supported through the **API Integration** method. Your backend creates the session with full parameter support, then passes the `session_token` to the SDK.

Read more about how the create session API works here:
https://docs.didit.me/reference/create-session-verification-sessions

```dart
// Your backend handles the full session creation:
// POST /v3/session/ with contact_details, expected_details, metadata, etc.
final sessionToken = await yourBackend.createSession(userId);

// The SDK only needs the token
final result = await DiditSdk.startVerification(sessionToken);
```

## Verification Results

Both `startVerification` and `startVerificationWithWorkflow` return a `Future<VerificationResult>`. The result is a sealed class — use pattern matching to determine the outcome.

### Result Types

| Type | Description | Fields |
|------|-------------|--------|
| `VerificationCompleted` | Verification flow completed | `session` (always present) |
| `VerificationCancelled` | User cancelled the flow | `session` (optional) |
| `VerificationFailed` | An error occurred | `error` (always present), `session` (optional) |

### SessionData

| Property | Type | Description |
|----------|------|-------------|
| `sessionId` | `String` | The unique session identifier |
| `status` | `VerificationStatus` | `approved`, `pending`, or `declined` |

### VerificationError

| Property | Type | Description |
|----------|------|-------------|
| `type` | `VerificationErrorType` | Error category (see table below) |
| `message` | `String` | Human-readable error description |

### Error Types

| Error Type | Description |
|------------|-------------|
| `sessionExpired` | The session has expired |
| `networkError` | Network connectivity issue |
| `cameraAccessDenied` | Camera permission not granted |
| `notInitialized` | SDK not initialized (Android only) |
| `apiError` | API request failed |
| `unknown` | Other error with message |

### Complete Result Handling Example

```dart
import 'package:didit_sdk/sdk_flutter.dart';

Future<void> verify(String token) async {
  final result = await DiditSdk.startVerification(token);

  switch (result) {
    case VerificationCompleted(:final session):
      switch (session.status) {
        case VerificationStatus.approved:
          print('Approved! Session: ${session.sessionId}');
          // User is verified — grant access
        case VerificationStatus.pending:
          print('Under review. Session: ${session.sessionId}');
          // Show "verification in progress" UI
        case VerificationStatus.declined:
          print('Declined. Session: ${session.sessionId}');
          // Handle declined verification
      }

    case VerificationCancelled(:final session):
      print('User cancelled.');
      if (session != null) {
        print('Session: ${session.sessionId}');
      }
      // Maybe show retry option

    case VerificationFailed(:final error):
      print('Error [${error.type}]: ${error.message}');
      // Handle error — show retry or contact support
  }
}
```

## API Reference

### `DiditSdk.startVerification(token, {config})`

Start verification with an existing session token.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `token` | `String` | Yes | Session token from the Didit API |
| `config` | `DiditConfig?` | No | SDK configuration options |

Returns: `Future<VerificationResult>`

### `DiditSdk.startVerificationWithWorkflow(workflowId, {...})`

Start verification by creating a new session with a workflow ID (Unilink Integration).

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `workflowId` | `String` | Yes | Workflow ID that defines verification steps |
| `vendorData` | `String?` | No | Your user identifier or reference |
| `config` | `DiditConfig?` | No | SDK configuration options |

Returns: `Future<VerificationResult>`

## Running the Example App

The repository includes a fully functional example app.

### iOS

```bash
cd example
flutter pub get
cd ios && pod install && cd ..
flutter run
```

To run on a real device, open `example/ios/Runner.xcworkspace` in Xcode, configure your signing team, and select your device.

### Android

```bash
cd example
flutter pub get
flutter run
```

## License

Copyright (c) 2026 Didit. All rights reserved.
