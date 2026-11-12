# didit_auth

Didit Authentication for Flutter.
Sign your app's end users up and in with the hosted Didit page (PKCE), or with a passkey.
Sessions stay in the iOS Keychain or the Android Keystore.
Read an access token for your backend, sign out, and run a step-up before a sensitive action.

This package wraps the native DiditAuth modules (`me.didit:didit-auth` on Android, `DiditSDK/Auth` or the `DiditAuth` Swift package product on iOS), pinned to native release **4.15.0**.
It has the same calls, result shapes and error codes as the React Native package.
Identity verification has its own package, [`didit_sdk`](https://pub.dev/packages/didit_sdk); both can be installed in one app because they pin the same native release.

## Requirements

| Requirement | Minimum |
|-------------|---------|
| Flutter | 3.3 |
| Dart | 3.11 |
| Android | API 23 (passkeys need Android 9 or later) |
| iOS | 15.0 (the hosted pages need iOS 17.4 at run time) |
| Android build toolchain | Kotlin 2.1.10+, Android Gradle Plugin 8.6.0+, Gradle 8.7+, JDK 17 |

Below iOS 17.4 the hosted page cannot return to an HTTPS redirect: `signIn` fails with the error code `browser_unavailable`, and so does `stepUp` when a check has to run.
Session, token and sign-out calls are not affected.
The plugin runs on Android and iOS only; on any other platform every call throws a `DiditAuthUnavailableException`.

## Install

```yaml
dependencies:
  didit_auth: ^0.1.0
```

```dart
import 'package:didit_auth/didit_auth.dart';
```

### Set up the redirect and passkeys

Didit sends the person back to your app with an HTTPS redirect; it accepts no custom URL schemes.
Register the redirect URI and copy the publishable key in the Didit console (Authentication, Developers), then follow the quickstart for each platform:

- Android: <https://docs.didit.me/authentication/quickstarts/android> (App Link, `DiditAuthRedirectActivity`, passkeys)
- iOS: <https://docs.didit.me/authentication/quickstarts/ios> (associated domains, passkeys)

### Android

Nothing else is needed: the plugin adds Didit's Maven repository (`https://raw.githubusercontent.com/didit-protocol/sdk-android/main/repository`, group `me.didit` only) to your build and resolves `me.didit:didit-auth:4.15.0` from it.
Declare the redirect activity in your app's `AndroidManifest.xml` as the quickstart shows.

### iOS

Swift Package Manager (Flutter 3.24+ with `flutter config --enable-swift-package-manager`): nothing else is needed, the `DiditAuth` product of `sdk-ios` resolves from GitHub.

CocoaPods: DiditSDK is not on the CocoaPods trunk, so your `ios/Podfile` names its podspec at the pinned version and sets the iOS 15 floor:

```ruby
platform :ios, '15.0'

target 'Runner' do
  use_frameworks!

  pod 'DiditSDK/Auth', :podspec => 'https://raw.githubusercontent.com/didit-protocol/sdk-ios/4.15.0/DiditSDK.podspec'

  flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))
end
```

With `didit_sdk` in the same app, keep its `DiditSDK/...` line from the `didit_sdk` README; `DiditSDK/Auth` is part of every variant, so you do not add a second line.

## Use

Create one `DiditAuth` per application and reuse it.

```dart
final auth = DiditAuth(
  publishableKey: 'pk_live_...',
  redirectUri: 'https://app.example.com/didit/callback',
);
```

### Sign in

```dart
final session = await auth.signIn(); // hosted page: sign-up and sign-in
final viaPasskey = await auth.signInWithPasskey(); // a passkey of this device
final passkeyId = await auth.registerPasskey(); // needs a session at most five minutes old
```

### Session, token and sign-out

```dart
final current = await auth.currentSession(); // DiditSession? - cached for 30 seconds
final fresh = await auth.currentSession(force: true); // asks Didit now
final token = await auth.getToken(); // String? - five-minute token for your backend
await auth.signOut();
```

`getToken` and `currentSession` return `null` when nobody is signed in.
Verify the access token on your backend against the issuer's JWKS.
Refresh tokens stay in native storage and never reach Dart.

A `DiditSession` has `userId`, `sessionId`, `applicationId`, `vendorData`, `email`, `emailVerified`, `phone`, `methods`, `mfaVerified`, `verified`, `organizations` and `expiresAt`.

### Step-up before a sensitive action

```dart
final result = await auth.stepUp(
  const DiditPayoutStepUp(amount: '900.00', currency: 'EUR'),
);
if (result.approved) {
  // Your backend confirms with GET step-up/{result.id}/ before it pays out.
}
```

`stepUp` also takes `DiditBankStepUp()` (adding or changing a bank account) and `DiditContactStepUp()` (changing the email or phone).
The result's `status` is `not_required`, `approved`, `pending`, `review`, `declined` or `expired`.
An app can be tampered with, Didit's record cannot: always read the outcome again on your backend.

## Errors

Every call throws a `DiditAuthException` carrying native DiditAuth's `code` and `message` unchanged, plus `status`, `fields` and `retryAfter` (seconds) when Didit sent them.
The codes are the same on Android and iOS and in the React Native package:

| Code | Meaning |
|------|---------|
| `cancelled` | The person closed the sign-in or step-up page |
| `invalid_state` | The page returned for a sign-in this app did not start |
| `not_signed_in` | The call needs a signed-in person |
| `passkey_cancelled` | The person dismissed the passkey prompt |
| `passkey_unavailable` | The device cannot run a passkey for this app |
| `browser_unavailable` | The page cannot be shown: no screen of the app is in the foreground, or iOS is older than 17.4 |
| `storage_unavailable` | The Keychain or Android Keystore could not keep the tokens |
| `invalid_publishable_key` | The publishable key is not valid |
| `invalid_redirect_uri` | The redirect is not a valid HTTPS address, or is not registered |
| `invalid_request` | The request is malformed, for example a payout without an amount |
| `network_error` | Didit could not be reached |
| `rate_limited` | Too many requests; wait `retryAfter` seconds |
| `server_error` | Didit answered with an error or an unexpected answer |
| `unspecified` | A native failure that is not a DiditAuth error |
| `ERR_DIDIT_AUTH_UNAVAILABLE` | The plugin is not available on this platform (`DiditAuthUnavailableException`) |

Codes of the Didit API pass through unchanged, for example `invalid_grant`, `method_unavailable` or `reauthentication_required`, so handle unknown codes.
`DiditAuthErrorCodes` has a constant for each code in the table.

```dart
try {
  await auth.signIn();
} on DiditAuthException catch (error) {
  if (error.code == DiditAuthErrorCodes.cancelled) return;
  if (error.code == DiditAuthErrorCodes.rateLimited) {
    // Try again after error.retryAfter seconds.
  }
  rethrow;
}
```

## Not in this release

Re-authentication (`reauthenticate`) and the bot score header arrive with a later native release and are not part of 0.1.0.

## License

MIT, see [LICENSE](LICENSE).
