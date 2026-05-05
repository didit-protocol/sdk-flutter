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
