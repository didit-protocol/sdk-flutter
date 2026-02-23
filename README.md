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
  didit_sdk: ^3.2.1
```

Then run:

```bash
flutter pub get
```

### iOS Setup

Add the DiditSDK podspec to your `ios/Podfile` (it's not on CocoaPods trunk):

```ruby
# Inside your target block:
pod 'DiditSDK', :podspec => 'https://raw.githubusercontent.com/didit-protocol/sdk-ios/main/DiditSDK.podspec'
```

Then install dependencies:

```bash
cd ios
pod install
```

### Android Setup

Add the following packaging rule to your `android/app/build.gradle.kts` inside the `android` block:

```kotlin
android {
    packaging {
        resources {
            pickFirsts += "META-INF/versions/9/OSGI-INF/MANIFEST.MF"
        }
    }
}
```

This resolves a duplicate metadata file shipped by the SDK's cryptography dependencies (BouncyCastle). Without it the build will fail with a `mergeDebugJavaResource` error.

## Permissions

### iOS

Add the following keys to your app's `Info.plist`:

| Permission | Info.plist Key | Description | Required |
|------------|----------------|-------------|----------|
| Camera | `NSCameraUsageDescription` | Document scanning and face verification | Yes |
| NFC | `NFCReaderUsageDescription` | Read NFC chips in passports/ID cards | If using NFC |
| Location | `NSLocationWhenInUseUsageDescription` | Geolocation for fraud prevention | Optional |

```xml
<key>NSCameraUsageDescription</key>
<string>Camera access is required for identity verification.</string>
<key>NFCReaderUsageDescription</key>
<string>NFC is used to read passport chip data for identity verification.</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>Location access is used to detect your country for identity verification.</string>
```

#### NFC Configuration (for passport/ID chip reading)

1. **Add NFC Capability** in Xcode:
   - Select your target > Signing & Capabilities > + Capability > Near Field Communication Tag Reading

2. **Add ISO7816 Identifiers** to `Info.plist`:
   ```xml
   <key>com.apple.developer.nfc.readersession.iso7816.select-identifiers</key>
   <array>
       <string>A0000002471001</string>
   </array>
   ```

### Android

The following permissions are declared in the native SDK's `AndroidManifest.xml` and merged automatically:

| Permission | Description | Required |
|------------|-------------|----------|
| `INTERNET` | Network access for API communication | Yes |
| `ACCESS_NETWORK_STATE` | Detect network availability | Yes |
| `CAMERA` | Document scanning and face verification | Yes |
| `NFC` | Read NFC chips in passports/ID cards | If using NFC |

Camera and NFC hardware features are declared as optional (`android:required="false"`), so your app can be installed on devices without these features.

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

### Method 1: Session Token (Recommended for Production)

Create a session on your backend using the [Create Verification Session API](https://docs.didit.me/sessions-api/create-session), then pass the token to the SDK:

```dart
// Your backend creates a session and returns the token
final sessionToken = await yourBackend.createVerificationSession(userId);

// Pass the token to the SDK
final result = await DiditSdk.startVerification(sessionToken);
```

This approach gives you full control over:

- Associating sessions with your users (`vendor_data`)
- Setting custom metadata
- Configuring callbacks per session

### Method 2: Workflow ID (Simpler Integration)

For simpler integrations, the SDK can create sessions directly using your workflow ID:

```dart
final result = await DiditSdk.startVerificationWithWorkflow(
  'your-workflow-id',
  vendorData: 'user-123',
  contactDetails: ContactDetails(email: 'user@example.com'),
  config: DiditConfig(loggingEnabled: true),
);
```

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

All fields are optional. If no config is provided, the SDK uses sensible defaults.

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

The SDK supports **40+ languages**. If no language is specified, the SDK uses the device locale with English as fallback.

#### Supported Languages

| Language | Code | Language | Code |
|----------|------|----------|------|
| English | `en` | Korean | `ko` |
| Arabic | `ar` | Lithuanian | `lt` |
| Bulgarian | `bg` | Latvian | `lv` |
| Bengali | `bn` | Macedonian | `mk` |
| Catalan | `ca` | Malay | `ms` |
| Czech | `cs` | Dutch | `nl` |
| Danish | `da` | Norwegian | `no` |
| German | `de` | Polish | `pl` |
| Greek | `el` | Portuguese | `pt` |
| Spanish | `es` | Portuguese (Brazil) | `pt-BR` |
| Estonian | `et` | Romanian | `ro` |
| Persian | `fa` | Russian | `ru` |
| Finnish | `fi` | Slovak | `sk` |
| French | `fr` | Slovenian | `sl` |
| Hebrew | `he` | Serbian | `sr` |
| Hindi | `hi` | Swedish | `sv` |
| Croatian | `hr` | Thai | `th` |
| Hungarian | `hu` | Turkish | `tr` |
| Armenian | `hy` | Ukrainian | `uk` |
| Indonesian | `id` | Uzbek | `uz` |
| Italian | `it` | Vietnamese | `vi` |
| Japanese | `ja` | Chinese (Simplified) | `zh` |
| Georgian | `ka` | Chinese (Traditional) | `zh-TW` |
| Montenegrin | `cnr` | Somali | `so` |

## Advanced Options

These options are only available with `startVerificationWithWorkflow`, where the SDK creates the session on your behalf.

### Contact Details (Prefill & Notifications)

Provide contact details to prefill verification forms and enable email notifications:

```dart
final result = await DiditSdk.startVerificationWithWorkflow(
  'your-workflow-id',
  contactDetails: ContactDetails(
    email: 'user@example.com',
    sendNotificationEmails: true,
    emailLang: 'en',
    phone: '+14155552671',
  ),
);
```

| Field | Type | Description |
|-------|------|-------------|
| `email` | `String?` | Email address for verification notifications |
| `sendNotificationEmails` | `bool?` | Whether to send status update emails |
| `emailLang` | `String?` | ISO 639-1 language code for notification emails |
| `phone` | `String?` | Phone number in E.164 format (e.g. `"+14155552671"`) |

### Expected Details (Cross-Validation)

Provide expected user details for automatic cross-validation with extracted document data:

```dart
final result = await DiditSdk.startVerificationWithWorkflow(
  'your-workflow-id',
  expectedDetails: ExpectedDetails(
    firstName: 'John',
    lastName: 'Doe',
    dateOfBirth: '1990-05-15',
    nationality: 'USA',
    country: 'USA',
  ),
);
```

| Field | Type | Format | Description |
|-------|------|--------|-------------|
| `firstName` | `String?` | — | Expected first name |
| `lastName` | `String?` | — | Expected last name |
| `dateOfBirth` | `String?` | `YYYY-MM-DD` | Expected date of birth |
| `gender` | `String?` | — | Expected gender |
| `nationality` | `String?` | ISO 3166-1 alpha-3 | Expected nationality (e.g. `"USA"`, `"GBR"`) |
| `country` | `String?` | ISO 3166-1 alpha-3 | Expected country of residence |
| `address` | `String?` | — | Expected address |
| `identificationNumber` | `String?` | — | Expected document ID number |
| `ipAddress` | `String?` | — | Expected IP address |
| `portraitImage` | `String?` | — | Base64-encoded portrait image for face comparison |

All fields are optional.

### Custom Metadata

Store custom JSON metadata with the session (not displayed to user):

```dart
final result = await DiditSdk.startVerificationWithWorkflow(
  'your-workflow-id',
  vendorData: 'user-123',
  metadata: '{"internalId": "abc123", "source": "mobile-app"}',
);
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

Start verification by creating a new session with a workflow ID.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `workflowId` | `String` | Yes | Workflow ID that defines verification steps |
| `vendorData` | `String?` | No | Your user identifier or reference |
| `metadata` | `String?` | No | Custom JSON metadata for the session |
| `contactDetails` | `ContactDetails?` | No | Prefill contact information |
| `expectedDetails` | `ExpectedDetails?` | No | Expected identity details for cross-validation |
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
