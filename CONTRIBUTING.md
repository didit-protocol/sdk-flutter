# Contributing

## Protect private information

This repository is public. Do not include customer, prospect, organization, or
contact names; email addresses; account/session identifiers; private support
details; private tracker keys; or links to private repositories and internal
tools in issues, pull requests, comments, commits, screenshots, logs, fixtures,
release notes, or packages. Describe a report anonymously and share identifying
context with maintainers only through an approved private channel.

## Verification

Run formatting, static analysis, and tests before opening a pull request.

- Dart: `flutter analyze && flutter test` at the repository root.
- Android plugin: `flutter build apk --config-only` in `example`, then `./gradlew :didit_sdk:testDebugUnitTest` in `example/android`.
- iOS plugin (macOS): `flutter build ios --debug --no-codesign` in `example`, then run Product > Test on the Runner scheme of `example/ios/Runner.xcworkspace` (or `xcodebuild test -workspace Runner.xcworkspace -scheme Runner -destination 'platform=iOS Simulator,name=<an iPhone simulator>'` in `example/ios`).
- iOS bridge (macOS, sudo): `tool/ios_bridge_test.sh [simulator udid]` runs a native `retryBlocked` result from Dart to the native SDK and back on a simulator, against a local stand-in for the verification API.
