# didit_sdk_core

The Didit Identity Verification SDK for Flutter, pinned to the **core** native SDK variant on both iOS and Android: smallest, manual capture only - no automatic capture, no NFC.

| | |
|---|---|
| Automatic capture | No |
| NFC passport reading | No |
| Minimum iOS | 13.0 |

It exposes exactly the same Dart API as [`didit_sdk`](https://pub.dev/packages/didit_sdk) - only the bundled native SDK differs.
Depend on exactly one of the `didit_sdk` packages:

```yaml
dependencies:
  didit_sdk_core: ^4.5.0
```

```dart
import 'package:didit_sdk_core/sdk_flutter.dart';
```

See the [`didit_sdk` README](https://pub.dev/packages/didit_sdk) for full setup and usage documentation - substitute `didit_sdk` with `didit_sdk_core` in import statements.
This package is generated from `didit_sdk` - do not edit it by hand.
