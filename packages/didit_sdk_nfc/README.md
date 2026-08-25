# didit_sdk_nfc

The Didit Identity Verification SDK for Flutter, pinned to the **nfc** native SDK variant on both iOS and Android: NFC passport reading without automatic capture.

| | |
|---|---|
| Automatic capture | No |
| NFC passport reading | Yes |
| Minimum iOS | 15.0 |

It exposes exactly the same Dart API as [`didit_sdk`](https://pub.dev/packages/didit_sdk) - only the bundled native SDK differs.
Depend on exactly one of the `didit_sdk` packages:

```yaml
dependencies:
  didit_sdk_nfc: ^4.7.2
```

```dart
import 'package:didit_sdk_nfc/sdk_flutter.dart';
```

See the [`didit_sdk` README](https://pub.dev/packages/didit_sdk) for full setup and usage documentation - substitute `didit_sdk` with `didit_sdk_nfc` in import statements.
This package is generated from `didit_sdk` - do not edit it by hand.
