# didit_sdk_autodetection

The Didit Identity Verification SDK for Flutter, pinned to the **autodetection** native SDK variant on both iOS and Android: automatic capture without NFC.

| | |
|---|---|
| Automatic capture | Yes |
| NFC passport reading | No |
| Minimum iOS | 13.0 |

It exposes exactly the same Dart API as [`didit_sdk`](https://pub.dev/packages/didit_sdk) - only the bundled native SDK differs.
Depend on exactly one of the `didit_sdk` packages:

```yaml
dependencies:
  didit_sdk_autodetection: ^4.5.1
```

```dart
import 'package:didit_sdk_autodetection/sdk_flutter.dart';
```

See the [`didit_sdk` README](https://pub.dev/packages/didit_sdk) for full setup and usage documentation - substitute `didit_sdk` with `didit_sdk_autodetection` in import statements.
This package is generated from `didit_sdk` - do not edit it by hand.
