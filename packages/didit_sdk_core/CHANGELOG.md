## 4.14.5

Pins the iOS and Android native SDKs exactly to 4.14.5.

No Dart API changes. The native changes below run inside the existing start-verification call and return the same `VerificationResult`.

- Android: every SDK resource now starts with `didit_`, so the SDK no longer replaces a host app's own resources (for example `ic_close`) and a host app's strings no longer change the SDK's copy. Anyone who customized the SDK's wording by overriding its resource names should use the application's copy overrides instead (the Texts tab in Customization in the console).
- iOS: no functional change; the version stays aligned.


## 4.14.4

Pins the iOS and Android native SDKs exactly to 4.14.4.

No Dart API changes. The native change below runs inside the existing start-verification call and returns the same `VerificationResult`.

- iOS and Android: Bank iD sign-in button on the method list, in Bank iD's official form. Czech sessions get the two-part verify button, every other country the logo alone, and the sign-in opens in the system browser.


## 4.14.3

Pins the iOS and Android native SDKs exactly to 4.14.3.

No Dart API changes. The native change below runs inside the existing start-verification call and returns the same `VerificationResult`.

- iOS: the selfie result screens show the sandbox banner only for sandbox sessions. Live sessions showed "SANDBOX · Test data only" there. Android has no functional change; the version stays aligned.


## 4.14.2

Pins the iOS and Android native SDKs exactly to 4.14.2.

No Dart API changes. The native changes below run inside the existing start-verification call and return the same `VerificationResult`.

- Both platforms: on the phone step, when the verification code cannot reach the person (the call failed or the number cannot be reached), the code screen now says so, with Change number and Try again / Call me again, instead of waiting forever. Telegram is offered first in Russia, Kazakhstan, Uzbekistan and Kyrgyzstan. The welcome and business verification start titles keep the form of address of the rest of the screen in Spanish, Catalan and Hebrew. In all 54 languages.
- Android: the Google Wallet step shows a generic wallet icon instead of the Google Wallet logo.


## 4.14.1

Pins the iOS and Android native SDKs exactly to 4.14.1.

No Dart API changes. The native changes below run inside the existing start-verification call and return the same `VerificationResult`.

- Both platforms: on the e-signature step, when the signing code could not be sent (the request was refused, a new code was asked for too soon, or there was no connection), the screen that asked for it stays, with a line that says why and a countdown to when the person can try again, instead of the generic error screen. The code screen says when the code could not be checked and checks the six digits as soon as they are typed; on Android it offers to fill in the code from the SMS with the person's consent. In all 54 languages.


## 4.14.0

Pins the iOS and Android native SDKs exactly to 4.14.0.

No Dart API changes. The native changes below run inside the existing start-verification call and return the same `VerificationResult`.

- Both platforms: phone verification offers a voice call (a call that reads the code out) for countries that list it, with "Get a call instead", "Call me with the code" and "Call again".
- Both platforms: signing documents at the qualified level (QES) says the qualified trust service provider texted the code, shows "Send a new code" after a provider failure, "Signing has ended" for an identity the qualified level cannot use, its own screen for a document that is too large, and a test-signature screen in the sandbox.
- Both platforms: ConnectID's Representative model names the roles and the client's logo before the bank list, asks for an explicit consent, and ends on a "Verified with ConnectID" screen with the shared details.
- Both platforms: UAE PASS uses the official "Sign in with UAE PASS" button, its opening, checking and confirmed screens, and the mandated messages for a cancelled, failed or unverified sign-in.
- Both platforms: the "Asked to redo" screen matches the web flow and the email, with one "step: reason" line per step to redo and an "Already done" line, in all 54 languages.


## 4.13.2

Pins the iOS and Android native SDKs exactly to 4.13.2. Native 4.13.1 was an Android-only interim release with the welcome screen change below; this release brings it to iOS too.

No Dart API changes. The native changes below run inside the existing start-verification call.

- Android: the plugin builds with Android Gradle Plugin 9 and its built-in Kotlin. It applies the Kotlin Gradle Plugin only when built-in Kotlin is off (AGP 8, or AGP 9 with `android.builtInKotlin=false`), so AGP 9 apps no longer fail or warn about it.
- iOS: a photo requested from a camera that opens but delivers no frames no longer crashes the host app. Every photo request first checks for a running camera session with an active video connection, and the screen shows its camera error or skip instead.
- Android: on the ID lookup selfie, a photo request from a camera that delivers no frames ends in the screen's camera error after 5 seconds instead of waiting forever.
- Both platforms: on the welcome screen, while the list of steps goes on below its bottom fade, a round "Scroll down" button sits horizontally centred on the list (also in right-to-left languages), as in the web flow. A tap scrolls the list down, the button hides at the end of the list and while a sheet is open, and it is a named, accessible button in every language the SDK supports.


## 4.13.0

Pins the iOS and Android native SDKs exactly to 4.13.0.

No Dart API changes. The changes below run inside the existing start-verification call.

- Both platforms: in the phone step, every +1 (US and Canada) number shows a short carrier disclosure under "Send code" ("Standard message and data rates may apply") with links to the SMS Terms and the Privacy Policy, in the person's language.
- Both platforms: the selfie oval now fits above its controls on short screens, and the green "Done" pill, the "Got it" after a document photo and the "Selfie taken" screen are gone: a captured photo goes straight to Processing.
- Both platforms: when document capture is only the fallback and a digital ID wallet leads, the wallet's launch screen offers the wallet alone, and a wallet retry keeps the verification open without a document link.
- Both platforms: a flag is drawn for every country code the backend can send, from one lookup, and never the wrong one.
- Both platforms: a sandbox scenario armed on an already started session now shows the backend's reason instead of a generic error.
- Android: the Credential Manager wallet reads "Verify with digital ID" (it can be answered by Google Wallet or any other Android wallet that holds a compatible ID). iOS does not offer this method.


## 4.12.2

Pins the iOS and Android native SDKs exactly to 4.12.2.

No Dart API changes. The changes below run inside the existing start-verification call.

- Both platforms: the welcome screen centres the logo (Didit's, or the customer's on white label) above the left-aligned title. iOS now draws the customer's logo 72 pt high, as Android and the web do, and the iOS resubmission screen shows the company block again.
- Both platforms: in the KYB key people step, "Add representative" opens with a representative role selected and saves the person under representatives even when the workflow switches some roles off. Before, the person could only be added as a beneficial owner and the step could not continue.
- Both platforms: in questionnaires, "Secured by" stays pinned under the button on short screens and at large text, the country picker of an address question is titled for the address, and an open dropdown takes the fields' corners.


## 4.12.1

Pins the iOS and Android native SDKs exactly to 4.12.1.

No Dart API changes. The changes below run inside the existing start-verification call.

- iOS: on an iPhone whose storage is full, the document and selfie captures keep their video. The camera's movie recording stopped at its first frame there and the SDK uploaded clips with no video, so the verification had no document, selfie or full session video. The SDK now records those captures in memory, and never uploads a recording without video frames.
- Both platforms: a server answer that lags two polls behind an early answer no longer reopens the step that was just answered, such as the NFC, selfie or document step, matching the web flow.


## 4.12.0

Pins the iOS and Android native SDKs exactly to 4.12.0.

No Dart API changes. The changes below run inside the existing start-verification call.

- Both platforms: wallet logos for every digital ID wallet the web flow shows (Mobile-ID, ConnectID, FTN, OneID, Bank iD, MojeID, FranceConnect, Auðkenni, the Estonian ID-card, GOV.UK Wallet), on the same white or black plate as the web.
- Both platforms: capture hints that say what to do when auto-capture is not running, a selfie detector that gives up shows the shutter at once, the welcome keeps its legal sentence pinned at large text sizes, the step label stays on one line, and a refused session start no longer offers a retry that cannot work.
- Both platforms: Switch camera beside the shutter on the document and selfie cameras, with Upload moved into Tips; the selfie camera gets the document camera's shutter row with Tips, the hint above the row and "Step 2 of 4 · Selfie".
- Android: the Select camera sheet names cameras "Front camera" and "Back camera", numbered "Back camera 2" when a side has several, in every language.
- Both platforms: nothing is captured automatically while a sheet is open over the document or selfie camera (Tips, Select camera, the exit confirmation). Detection pauses, and a capture needs the full stable hold again once the sheet closes.


## 4.11.0

Pins the iOS and Android native SDKs exactly to 4.11.0. This release also carries everything planned for 4.10.0, which was never published to pub.dev.

- Both platforms: the redesigned flow shell, with a new top bar, progress in words, a rebuilt welcome screen and clearer error messages.
- Both platforms: Bank verification never ends in a dead end. Countries without a bank route offer a statement upload or continuing without a bank, and an account check counts its own attempts.
- iOS: document capture focuses reliably on close-up cards.
- Both platforms: automatic capture is available in every variant, using the Didit tiny detectors (TensorFlowLite on iOS and MediaPipe on Android are removed). The `autodetection` variant and the `didit_sdk_autodetection` package are deprecated and identical to `core` / `didit_sdk_core`; switch to `didit_sdk_core`. The Android `didit-sdk-autodetection-play` artifact is no longer published.
- New native steps run inside the existing start-verification call, with no new Dart API:
  - Bank verification: the person approves in the system browser, on the bank's page or a page Didit hosts. No setup.
  - Location verification: on iOS it is opt-in with `$DiditSdkIosLocationEnabled = true` in your Podfile (or `DIDIT_SDK_IOS_LOCATION_ENABLED=true`), which selects the `DiditSDK/All-Location`, `Core-Location` or `NFC-Location` subspec; Swift Package Manager cannot select it through this plugin yet. On Android `didit-sdk-core` declares `ACCESS_FINE_LOCATION` and `ACCESS_COARSE_LOCATION`; remove them with `tools:node="remove"` if you never run the step. Without it the step reports that the device cannot place the person. See the README for the Info.plist purpose strings.
  - Electronic signature (Sign documents).
  - Biometric consent, when Didit's backend requires it.
- Both platforms: a "No camera found" screen with a Copy link action. Verification steps the SDK version does not support show update-app guidance and return a failed result.
- iOS: the native framework is smaller because translations moved out of the binary. A verification ended by reaching the maximum number of attempts is reported as `retryBlocked` instead of `unknown`.
- Both platforms: active liveness recovers when its completion callback is missed or arrives late, instead of waiting or returning to the intro.
- Android: the native artifacts need Kotlin 2.1.10+, Android Gradle Plugin 8.6.0+, Gradle 8.7+ and JDK 17.


## 4.9.1

Pins the iOS and Android native SDKs exactly to 4.9.1.

- Both platforms: the document and proof of address country pickers open on the country detected from the user's IP address. When that lookup finished after the screen appeared, they used to stay on the first country in the list (Afghanistan); they now switch to the detected country, without overriding a country set in the session or one the user picked (#23).
- Android: a questionnaire's section header and fields are shown in the SDK language. A questionnaire authored in one language with translations no longer shows its default-language header above translated fields.
- Android: NFC passport scanning no longer crashes with a missing `org.jmrtd.BACKey` class in the `didit_sdk` (all features) package.
- Both platforms: improved Russian and Kyrgyz verification copy.


## 4.9.0

Adds the opt-in `showLanguageSelector` configuration option.

When enabled, users can change the verification language from the welcome screen using the same compact, searchable selector as the web verification flow.
The selector remains hidden by default.

Pins the iOS and Android native SDKs exactly to 4.9.0.


## 4.8.0

- Native SDKs 4.8.0 on both platforms.
- Both platforms: ID verification methods. A country whose configuration offers a national ID-number lookup, a wallet sign-in, or both now presents them next to document capture on one entry screen, with each alternative route under its own heading. The lookup collects the fields that country asks for, validates them on the device, and falls back to document capture when the configuration allows it. This is the flow the web widget already ran.
- Both platforms: a rejected questionnaire submit now shows the reason the backend gave instead of a generic failure.
- iOS: every document row on the ID verification methods entry screen draws its own artwork instead of one generic page glyph, and a missing asset now draws an unmistakable placeholder rather than a plausible substitute symbol.
- Android: a workflow with two ID steps in a row no longer keeps the first step's screen over the second.
- Android: an ID-number lookup is never sent twice from one tap. Lookup and wallet-start requests are one-shot, so a connection failure no longer spends a second registry attempt before the flow sees the first fail.

## 4.7.5

- Native SDKs 4.7.5 on both platforms: iOS moves from 4.7.2 to 4.7.5, Android from 4.7.4 to 4.7.5.
- Both platforms: KYB company search now falls back to manual company entry when the business registry reports that it has no coverage for the selected country, not only when the registry is unavailable. That response previously left the user on the search screen with an error and a search that could never succeed.
- Both platforms: the KYB country pickers on the company search, confirmation and manual-entry screens now list only the registry-enabled countries resolved for the session, instead of every ISO country. Sessions from a backend that does not send the resolved list keep the previous behaviour unchanged.
- Both platforms: questionnaire questions defined on a workflow graph node now render and submit using the graph node's input type instead of the stale type on the static section item, so a question the graph defines as an upload renders the upload control and is submitted through the multipart file path.
- Android: passive liveness no longer fails with `UNEXPECTED_CAMERA_ERROR` on devices that expose usable cameras but no front lens. Camera options are now built from the cameras CameraX will actually bind, so such a device no longer falls back to requesting a front camera that cannot bind.
- Android: the front-camera selfie taken during document-front capture is now bounded and retried - up to 3 attempts within an 8 second budget, failing fast on permanent device facts such as a missing front lens, and reporting a typed failure reason instead of an opaque null. A camera that never called back previously left the capture suspended forever, so the back-camera preview stayed blank with no error.
- Android: document capture no longer reports `CAMERA_TIMEOUT` while it is still waiting for the camera permission dialog or for the front-camera selfie pre-capture. The stall timer is armed only once the preview can exist, so it no longer spends its restart attempts tearing down a session that is still binding.

## 4.7.4

- Android native SDK 4.7.3 -> 4.7.4. Active liveness now keeps the camera view visible while the camera pipeline starts up, fixing the Android 16 / API 36 preview starvation where `cameraReady` fired but no camera preview ever appeared.
- iOS: no changes - still pinned to native SDK 4.7.2, which has no 4.7.4 release. The fix was specific to Android camera startup.

## 4.7.3

- Android native SDK 4.7.3. Fixes the "Try Again", "Scan the front" and "Scan Back" buttons doing nothing on the upload status sheets on physical Android devices (didit-protocol/sdk-android#8). The sheets' full-screen touch-blocking overlay consumed every pointer event, and Compose cancels a button's in-progress tap when an ancestor consumes a MOVE event - which a real finger tap always produces between DOWN and UP. Emulator mouse clicks have no MOVE in between, so the flow only broke on real hardware.
- iOS: no changes - still pinned to native SDK 4.7.2, which has no 4.7.3 release. The bug was specific to Jetpack Compose touch dispatch.

## 4.7.2

- Native SDKs 4.7.2 on both platforms.
- Both platforms: a document or proof-of-address upload that never reached the server no longer leaves the flow spinning. An upload proven not to have been delivered is now reported as a failure with a retry, and the recovery poll that follows a genuinely ambiguous upload is bounded instead of running forever against a server the device cannot reach.
- Both platforms: per-step welcome copy overrides (`welcome.step.document`, `welcome.step.selfie`, `welcome.step.questionnaire`) now resolve against their own workflow step instead of always the first one.
- Android: fixes a crash on the completion screen as the result icon's animation settled (observed on Android 16).

## 4.7.1

- Native SDKs 4.7.1 on both platforms.
- iOS: fixes consumer builds failing with `no such module 'TensorFlowLite'` - the 4.7.0 `all` and `autodetection` binaries leaked an internal import into their Swift interface (didit-protocol/sdk-ios#9). The dependency is implementation-only again and the release pipeline now gates on the emitted interface.
- Android: process-death capture recovery no longer resurrects a dead flow, and its diagnostics are attributable.
- Both platforms: `welcome.title` copy overrides now apply on whitelabel apps.
- The device locale is now propagated into the verification session when no `languageCode` is set; explicit Hebrew (`he`, with legacy `iw` normalized) is preserved for token and workflow sessions.

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

* Initial release: the didit_sdk Flutter plugin pinned to the core native SDK variant on both platforms (smallest, manual capture only - no automatic capture, no NFC; minimum iOS 13.0). Supports both Swift Package Manager and CocoaPods on iOS.