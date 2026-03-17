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
