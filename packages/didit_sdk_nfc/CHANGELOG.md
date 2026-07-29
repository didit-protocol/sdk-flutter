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
