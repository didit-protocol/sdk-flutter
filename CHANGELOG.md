## 4.7.0

- Native SDKs 4.7.0 on both platforms.
- iOS: document and face auto-capture now run on a leaner TFLite engine instead of MediaPipe - about 12 MB smaller to download and roughly 8.5 MB smaller inside the app, detection behavior verified frame-for-frame identical on a physical-device matrix before release, and document inference about 40% faster.
- iOS: auto-capture inference degrades gracefully through a runtime retry ladder; total engine failure still falls back to manual capture, never a crash.
- Android: the native SDK gained an optional `didit-sdk-autodetection-play` artifact that runs auto-capture on the Google Play services ML runtime (~43 MB smaller universal APK). This package's `diditSdkAndroidVariant` options are unchanged in this release; wrapper-level opt-in support is planned as a follow-up.
- Both platforms: new session diagnostics (engine selection and inference latency) help support teams pinpoint device-specific capture issues.

## 4.6.0

- Native SDKs 4.6.0 on both platforms.
- Smaller SDK: every iOS variant is 7 to 8 MB smaller on device - build metadata and unused media are no longer embedded in the shipped frameworks.
- Android: WalletConnect wallet-signing now ships as the optional `me.didit:didit-sdk-wallet` artifact instead of being bundled in `didit-sdk-core`, shrinking every integration that does not use it and dropping its JitPack-only dependencies from slim variants. The full `didit-sdk` bundle (the `all` variant) is unchanged. Slim-variant apps that use native wallet signing must add the new artifact; without it, wallet-ownership flows complete in the browser instead.
- iOS: NFC chip-read failures now surface as localized errors in the scan sheet and are reported as session events for server-side visibility.
- Both platforms: support for application-scoped copy overrides.
- iOS: improved camera diagnostics during liveness capture.

## 4.5.3

- Android: fixed a hard crash of the host app right after passive-liveness selfie capture on high-megapixel cameras (reported on Samsung Galaxy S25 Ultra): captured face images are now capped at 4096px before processing and upload, and video segment recorder finalization is hardened so a codec failure can no longer take the process down.
- Android: if a capture ever does kill the app process, the SDK now detects it on the next launch and reports a `CAPTURE_PROCESS_DEATH` diagnostic event, making these crashes visible server-side instead of silent.
- Android: Hebrew localization now loads the complete translation set - previously large parts of the flow fell back to English.
- iOS: no source changes (rebuilt at 4.5.3 for version lockstep).
- Fixed the iOS Swift Package Manager manifest pinning native DiditSDK 4.5.0: wrapper releases built with SPM since 4.5.1 silently shipped native 4.5.0. SPM builds now get the declared native version.

## 4.5.2

- Android: fixed a fatal `NoSuchMethodError` crash (`FlowLayoutKt.FlowRow`) in host apps that resolve Jetpack Compose 1.8+/1.9, hit at the selfie upload sheet and in KYB screens (didit-protocol/sdk-react-native#33). The native SDK no longer uses experimental Compose layout APIs, making it binary-compatible with any host Compose version from its 1.7 floor upward.
- iOS: no changes (rebuilt at 4.5.2 for version lockstep).

## 4.5.1

* Native SDKs 4.5.1 on both platforms: the white-label page background now fills the top and bottom safe areas on iOS (fixes the letterboxed look on custom dark themes), and the status bar / system bar icon style follows the theme background on both platforms, with a camera-screen override so icons stay readable over camera previews.

## 4.5.0

* Native SDKs 4.5.0 on both platforms: the image-capture review screen now defaults to off, matching the backend, so a capture is no longer stranded behind a confirm step the workflow never enabled
* iOS: the front-camera document preview no longer shows mirrored when the camera session finishes configuring after the view is built
* Android: SMS OTP one-tap autofill, plus device and runtime integrity signals for injection-attack detection
* Both platforms: RTL layout and Arabic support
* Android: the minimum is now declared as API 23 on every module. That was always the real floor, set by Reown AppKit inside the native core, and modules previously declaring 21 could not actually be consumed at that level
* All Didit SDKs now share the same version number

## 4.4.1

* Native SDKs 4.3.1 on both platforms: the face flow no longer resets to its intro screen when the upload response advances within the face family (FACE_MATCH / AGE_ESTIMATION); the flow now waits for the backend to settle and navigates once

## 4.4.0

* The smaller native SDK variants are now available under BOTH Swift Package Manager and CocoaPods via standalone packages with an identical Dart API: `didit_sdk_core` (manual capture only, iOS 13.0+), `didit_sdk_autodetection` (automatic capture without NFC, iOS 13.0+), and `didit_sdk_nfc` (NFC without automatic capture, iOS 15.0+). Depend on exactly one of the `didit_sdk` packages; each variant package pins the matching native SDK on both iOS and Android.
* `didit_sdk` itself is unchanged (full native SDK by default) - existing Swift Package Manager and CocoaPods setups, including `$DiditSdkIosVariant`, keep working as before.
* No Dart API changes.

## 4.3.1

* iOS: Swift Package Manager support. The plugin now ships a Swift package alongside the existing CocoaPods podspec, so apps built with Flutter's SPM mode consume the native DiditSDK automatically with no Podfile configuration. The SPM integration installs the complete native SDK (`all` variant) and requires an iOS 15.0+ deployment target; CocoaPods integration and variant selection are unchanged.
* iOS: the privacy manifest (PrivacyInfo.xcprivacy) is now bundled with the plugin on both integration paths.

## 4.3.0

* Native SDKs 4.3.0 on both platforms: redesigned document/face upload status with a full-screen, theme-native view and an animated per-character "thinking" status line (localized), per-country document type ordering, KYB UBO/shareholder role hiding, un-mirrored front-camera preview, and capture/build fixes
* iOS: the native dependency was still pinned to 4.1.0 in the 4.2.0 release, so iOS apps never received the 4.2.0 sandbox test-mode features; the pin now correctly tracks the native release (4.3.0)
* Android: the plugin now injects the JitPack repository alongside the Didit Maven repository, fixing resolution of the SDK's transitive wallet dependencies (Reown/WalletConnect, KEthereum)

## 4.2.0

* Sandbox (test-mode) support in the native SDKs: banner on every screen, bundled sample documents for ID/POA/Document AI uploads, scenario picker with Verified / Needs review / Declined outcomes, any-value guidance on email and phone steps
* Update native iOS SDK to 4.2.0
* Update native Android SDK to 4.2.0

## 4.1.0

* Update native iOS SDK to 4.1.0
* Update native Android SDK to 4.1.0
* Native wallet-ownership verification flow and transaction submission (`submitTransaction` / `getTransaction`) with required-action auto-launch (both platforms); Android also includes WalletConnect message signing
* New document quality-check screen before upload, and the full-color Didit logo with SVG white-label support (both platforms)
* KYB company search now uses two separate fields — company name and registration number — instead of a single unified query (both platforms)
* Requests now send an `X-Didit-Device-Model` header used for backend IP-analysis / device identification (both platforms)
* Fixes: passive liveness no longer gets stuck after tapping Continue and records correctly on iPhone 17 (iOS); front-camera document images are no longer mirrored on upload; the KYB processing screen could stall and the colored logo rendered incorrectly on some devices (Android)
* No breaking changes to the public Flutter API

## 4.0.9

* Update native iOS SDK to 4.0.9
* Update native Android SDK to 4.0.9
* Questionnaire: fields are now validated against their expected format before the step can be submitted, with a localized inline error message shown on invalid input (both platforms)
* Questionnaire: improved the inline validation error UI/UX for text, number, and text-area fields (both platforms)
* KYB key people: the person/company editor now shows company-appropriate labels and placeholders (company name, country of incorporation), and the key-people field definitions are parsed whether the backend returns them as strings or objects — preventing a deserialization crash (Android)
* Add internal front-camera orientation diagnostics (LOG telemetry) to investigate the iPhone 17 / Center Stage preview and recorded-video rotation — no user-facing change (iOS)
* No breaking changes: this release tracks the native 4.0.9 SDKs with no Flutter API changes

## 4.0.8

* Update native iOS SDK to 4.0.8
* Update native Android SDK to 4.0.8
* Add the Document AI verification step — prompts the user to upload the requested document(s) for AI-based data extraction, localized across all supported languages (both platforms)
* KYB: the document-upload step now lists the fields the uploaded document must clearly show (company name, type, incorporation date, jurisdiction of registration, registered address), and the key-people ownership percentage is now optional unless the session marks it required (both platforms)
* Fix passive-liveness video recorded horizontally stretched on iPhone 17 / 17 Pro / 17 Pro Max — the new Center Stage front sensor is now pinned to a portrait orientation (iOS)
* Fix the active-liveness face intro screen briefly appearing behind the processing overlay when the liveness step finishes (iOS)
* Correct the success and failure status texts shown after a face (liveness) upload (iOS)
* Hide the document detection corner guides when auto-detection isn't bundled (Core/NFC variants) or fails to load — only the static document frame guide remains (both platforms)
* Fix a KYB company-select crash when the registry returns accounts/industries as an object/string instead of an array (Android)
* No breaking changes: this release tracks the native 4.0.8 SDKs with no Flutter API changes

## 4.0.6

* Update native iOS SDK to 4.0.6
* Update native Android SDK to 4.0.6
* iOS: fix the App Store privacy-manifest rejection ITMS-91061 (and the sibling signature check ITMS-91065) for `OpenSSL.framework` — the native SDK now resolves OpenSSL-Universal 3.3.3001, which ships its own `PrivacyInfo.xcprivacy` and code signature; the NFC dependency `NFCPassportReader` was bumped 2.1.2 → 2.3.0 and verified end-to-end against a real chip read. No API change
* Android: add PACE (Password Authenticated Connection Establishment) support for NFC passport / ID chip reading
* KYB on both platforms: new company card, key-people and associated-parties screens, with key-people reuse across steps
* KYB on both platforms: a country-style US state selector in company search and confirmation (Android replaces the old state dropdown; iOS adds the selector), white-labeled company country/state search inputs with a region label, and an editable company country in the confirmation view
* KYB on both platforms: key-people data is now prefilled/preserved when the preceding step is backend-only, and email is no longer required for a key person when KYC isn't required for them
* KYB fixes: company selection failing to advance on partial registry data (both platforms), company-search auto-detection (Android), and accepted-country resolution for alpha-2 codes (Android)
* Fix the backend-processing loader getting stuck on the AML screening step (both platforms)
* Fix country/region display issues: some countries showed their alpha-3 code instead of the country name (both platforms); the flag not updating when changing the selected country (iOS); dropdown chevron visibility in KYB and document country inputs (Android)
* White-label / UI fixes: incorporation date-picker colors and KYB company input caret color (Android); document back-scan preview rotation, country/state picker search-icon visibility, start-screen feature icons aligned with Android & web, phone country picker aligned with the KYB selector, and KYB button spacing/separator cleanup (iOS)
* Add Russian ID & passport document-override translations, plus a general translations refresh, on both platforms
* Fix the iOS verification UI opening twice (Flutter plugin)
* No breaking changes: this release tracks the native 4.0.6 SDKs with no Flutter API changes

## 4.0.5

* Update native iOS SDK to 4.0.5
* Update native Android SDK to 4.0.5 (Android moves directly from 4.0.3 to 4.0.5 to stay in lockstep with iOS — there was no separate native Android 4.0.4)
* iOS: fix App Store rejection ITMS-90338 — the bundled native libraries (MediaPipe's RE2 / ICU / TensorFlow Lite) are no longer exported in the framework's dyld export trie, so App Store / TestFlight uploads of apps embedding the SDK are no longer flagged for the `re2::*` private-symbol collision. No API or runtime change
* Align every input and selector to the white-label theme on both platforms (text fields, OTP, dropdowns, country/phone pickers, questionnaire fields); unselected radio buttons now use the selected color at reduced opacity so they stay visible on every theme
* Align the KYB screens to the white-label theme on both platforms: documents upload view, key-people cards and editor, the awaiting-users view, and company search/results — including status badges, low-contrast text/icons, and the "enter company data manually" link color
* Fix passive liveness on both platforms: Android no longer shows a frozen preview after capture (the camera restarts correctly on retry), iOS no longer occasionally exceeds the backend upload size limit, and face-image compression now matches the web frontend
* Android: fix the KYB accepted-countries list disappearing when navigating back to the company search
* Add Algeria-specific NFC intro videos (`DZA`) for ID and passport on both platforms; the instructional video is now resolved from the document's detected country
* iOS: suppress the camera shutter sound on still capture (iOS 18+, where allowed) and fix a stretched / rotated front-camera preview on newer devices
* No breaking changes: this release tracks the native 4.0.5 SDKs with no Flutter API changes

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