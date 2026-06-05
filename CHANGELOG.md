## 4.0.4

* Update native iOS SDK to 4.0.4
* iOS: improve the post-active-liveness loader — dismiss the liveness WebView immediately on success and show the native processing/success sheet over an opaque background, then cross-fade into the next step, removing the residual blank/flash that could appear between active liveness and the next step
* Android SDK unchanged at 4.0.3
* No breaking changes: no Flutter API changes

## 4.0.3

* Update native Android SDK to 4.0.3
* Update native iOS SDK to 4.0.3
* Pin both native SDKs to an exact `4.0.3` version — the iOS dependency was previously a floating `~> 4.0`, and the iOS podspec source is now tag-pinned to `4.0.3` — so a given plugin release always resolves the same tested native SDKs on both platforms
* Add an active-liveness backend-processing loader shown natively after the liveness step while the session finishes processing on the backend — rotating localized status messages with a smooth transition into the next step (data-driven, no Flutter API change)
* Add native `Social Security Card` (`SSC`) document type support so document selectors on both platforms match the web frontend's full document list (data-driven, no Flutter API change)
* Fix front-camera document capture being saved mirrored — the captured and uploaded document image is now un-mirrored on the front lens, while the live preview and selfie/liveness capture stay mirrored as before
* Add proper retry error messaging for liveness and face-match failures, translated across all supported locales
* iOS: fix an active-liveness failure that could occur when the network connection (Wi-Fi) dropped during the liveness WebView flow
* iOS: remove the unused Location usage — the SDK no longer links `CoreLocation` or requests location, so you can drop `NSLocationWhenInUseUsageDescription` from your app's `Info.plist`
* Android: KYB document upload now only requests the required document subtypes
* Android: stop emitting a false worker-service failure log event (auto-detection not bundled, or running on API < 24, are no longer reported as errors)
* Emit a Tier-B device-class `composite_hash` fingerprint (`X-Didit-FP-Hash` header) for parity with the web SDK and the backend device-identification contract
* No breaking changes: this release tracks the native 4.0.3 SDKs with no Flutter API changes

## 4.0.2

* Update native Android SDK to 4.0.2
* Update native iOS SDK to 4.0.2
* Add native `Tax Card` (`TC`) document type support (data-driven, no Flutter API change) so document selectors on both platforms now match the web frontend's full document list, including the India `PAN Card (Permanent Account Number)` override
* Honor the session-level `expected_document_types` whitelist so a session that restricts allowed document types now applies the same filter natively on both platforms
* Add new public `CameraLens` enum (`front` / `back`) and four new `DiditConfig` options that expose the native camera configuration:
  * `defaultDocumentCamera` (defaults to native `back`) — lens used when first entering the document capture screen
  * `defaultLivenessCamera` (defaults to native `front`) — lens used when first entering the liveness (passive face) capture screen
  * `showDocumentCameraSwitchButton` (defaults to `true`) — hide to lock the user to `defaultDocumentCamera`
  * `showLivenessCameraSwitchButton` (defaults to `true`) — hide to lock the user to `defaultLivenessCamera`
  * Falls back to whichever camera is available when the requested lens isn't present on the device, and the in-capture switcher is automatically hidden on single-camera devices regardless of the `show…SwitchButton` flag
* Add three previously-unbridged `DiditConfig` options that mirror the native Configuration surface:
  * `showCloseButton` (defaults to `true`) — show the close (X) button on verification step screens
  * `showExitConfirmation` (defaults to `true`) — show a confirmation dialog when the user attempts to exit
  * `closeOnComplete` (defaults to `false`) — auto-dismiss the verification UI when complete
* Fix iOS selected-country / selected-document badges on the upload screen to use the white-label `bc-pill-text` token for the title text (was incorrectly using `bc-primary`)
* Fix iOS manual capture button disappearing after the user switches the camera mid-session on the liveness and document capture screens — the same delayed re-show timer used on first appear now also fires after each lens swap
* No breaking changes: all new `DiditConfig` fields are optional with defaults matching the native SDKs

## 4.0.1

* Fix iOS variant selection getting silently downgraded to `all` whenever `flutter build` ran. Inline env vars set on the host shell do not survive `flutter build`'s implicit `pod install`, so a `DIDIT_SDK_IOS_VARIANT=core flutter build` would still ship the full 38 MB MediaPipe binary instead of the 6 MB Core slice. The iOS variant is now selected via `$DiditSdkIosVariant` set in the host app's `ios/Podfile`, which CocoaPods re-reads on every install. `DIDIT_SDK_IOS_VARIANT` is kept as a CI fallback.
* Verified end-to-end on a Flutter Release build per variant: `core` produces a 6.0 MB DiditSDK Mach-O, `nfc` 6.6 MB, both with zero MediaPipe symbols.
* See the iOS Setup section in the README for the new snippet to copy into your `ios/Podfile`.

## 4.0.0

* Update native Android SDK to 4.0.0
* Update native iOS SDK to 4.0.0
* Add explicit native SDK variant selection on Android and iOS: `all`, `core`, `autodetection`, and `nfc`
* Keep `all` as the default full SDK variant
* Add lightweight `core` variants for apps that only need manual capture
* Add `autodetection` variants for apps that need automatic capture without NFC
* Add `nfc` variants for apps that need passport chip reading without automatic capture
* Remove legacy NFC-only variant switches in favor of explicit variant selection

## 3.7.2

* Update native Android SDK to 3.5.10
* Update native iOS SDK to 3.6.2
* Add Mongolian language support on Android and iOS
* Fix iOS start-screen EXC_BAD_ACCESS crash on iOS 13-17 caused by a Swift runtime symbol unavailable before iOS 18
* Fix Android front-camera anti-spoofing selfie capture stalling on Oppo, Realme, and Huawei devices
* Fix Android questionnaire crashes when graph branches omit optional IDs
* Improve Android header back arrow behavior in phone, email, and questionnaire flows
* Improve Android white-label colors for country selectors, questionnaire inputs, and KYB chips
* Add device fingerprint headers on Android verification API calls
* Add localized translations for special-case countries

## 3.7.1

* Update native Android SDK to 3.5.8
* Fix front camera anti-spoofing selfie capture stalling on Oppo, Realme, and Huawei devices

## 3.7.0

* Update native iOS SDK to 3.6.0
* Update native Android SDK to 3.5.7

## 3.6.0

* Update native iOS SDK to 3.4.1
* Add iOS no-NFC installation support through `DIDIT_SDK_IOS_NFC_ENABLED=false`
* Keep iOS NFC enabled by default while allowing apps to remove `NFCPassportReader`, CoreNFC-linked reader code, and OpenSSL by selecting `DiditSDK/Core`
* Document iOS privacy keys, NFC entitlements, provisioning requirements, and CocoaPods cleanup when switching NFC modes

## 3.5.0

* Update native Android SDK to 3.5.5
* Update native iOS SDK to 3.3.4
* Add native KYB verification flow support
* Add Kazakh language support and expand KYB/session translations
* Add awaiting-users flow support with full next-step routing
* Add redesigned native start screen with feature icons, legal consent, and close button
* Improve backend step recovery after interrupted, ambiguous, or failed responses
* Improve document capture quality, cropping, compression, and upload readability
* Fix verification flow getting stuck after upload fallback recovery
* Fix active liveness WebView language handling
* Fix Android document and face overflow detection
* Fix Android close button visibility and native input/text color styling
* Fix Android white-label theme flash on completion
* Add iOS SDK version/integration metadata and camera/video error LOG events

## 3.4.5

* Handle new RetryBlocked error variant from native Android SDK 3.4.4

## 3.4.4

* Fix Swift 6 compile error: add @unknown default to exhaustive switch on DiditSDK enums
* Update native iOS SDK to 3.2.11 (fix PDF file upload in questionnaire on iOS 26)
* Update native Android SDK to 3.4.4

## 3.4.3

* Update native Android SDK to 3.4.3 (Kyrgyz language support, new session step fields)
* Update native iOS SDK to 3.2.8 (fix SPM + Xcode 26 Archive signature failure)

## 3.4.2

* update native android sdk to 3.4.2
* fix document back upload loop when backend returns ocr_back on back side
* fix step transition freeze when same step type repeats
* fix questionnaire translations and file upload on samsung devices
* fix responsive navigation bar insets on samsung and other devices
* add configurable close/exit behavior (showCloseButton, showExitConfirmation, closeOnComplete)

## 3.4.1

* update readme with correct api references and integration naming

## 3.4.0

* update native android sdk to 3.4.0
* fix r8/proguard crashes in release builds (mediapipe, flogger, gson, retrofit)
* fix verification activity theme crash on android
* resolve native android sdk from remote github maven repository
* remove bundled aar from plugin package
* align ios swift bridge with native sdk api changes
* fix: remove invalid contactdetails, expecteddetails, and metadata parameters from workflow verification
* bump ios podspec to 3.4.0

## 3.3.4

* Add consumer ProGuard/R8 rules to prevent release build crashes
* Fix `java.lang.Class cannot be cast to java.lang.reflect.ParameterizedType` in release mode

## 3.3.3

* Fix backend-only step handling (AML, DATABASE_VALIDATION, IP_ANALYSIS) on Android
* Fix iOS SDK freeze on Continue button after KYC+AML flow
* Update native Android SDK to 3.3.3
* Update native iOS SDK to 3.2.3

## 3.3.2

* Fix camera permission handling for active liveness on Android
* Update native Android SDK to 3.3.2

## 3.3.1

* Fix Android 16KB page alignment issue for Android 15+ devices
* Update native Android SDK to 3.3.1 (MediaPipe 0.10.29, CameraX 1.4.2)
* Align Flutter SDK version with native Android SDK version

## 3.2.1

* Align with native SDK v3.2.1 for both iOS and Android
* Fix Swift 6 build error on iOS
* Fix Montenegrin (cnr) language code issue on Android

## 3.2.0

* Align with native SDK v3.2.0 for both iOS and Android
* Translation fixes (Uzbek escaping)
* Updated native dependencies: iOS DiditSDK 3.2.0, Android didit-sdk 3.2.0

## 0.1.0

* Initial release
* Wraps native DiditSDK for iOS (3.1.1) and Android (3.0.0)
* Session token and workflow ID verification methods
* Configuration options: language, font, logging
* Contact details and expected details for workflow sessions
* Full TypeScript-like sealed class result handling
