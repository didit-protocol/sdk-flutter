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

* Initial release: the didit_sdk Flutter plugin pinned to the nfc native SDK variant on both platforms (NFC passport reading without automatic capture; minimum iOS 15.0). Supports both Swift Package Manager and CocoaPods on iOS.
