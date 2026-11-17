import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:didit_sdk/sdk_flutter.dart';

// tool/ios_bridge_test.sh runs this on an iOS simulator against tool/stand_in_api.py,
// which answers the native SDK's session request the way the verification API answers
// a person with no retries left. Without the stand-in the request would reach the real
// API, so the test is skipped.
const _standInApi = bool.fromEnvironment('DIDIT_STAND_IN_API');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'the native retryBlocked callback reaches Dart as retryBlocked',
    (WidgetTester tester) async {
      final result = await DiditSdk.startVerificationWithWorkflow(
        'retry-blocked-workflow',
      );

      expect(result, isA<VerificationFailed>());
      final failed = result as VerificationFailed;
      expect(failed.error.type, VerificationErrorType.retryBlocked);
      expect(failed.session?.sessionId, 'retry-blocked-session');
      expect(failed.session?.status, VerificationStatus.declined);
    },
    skip: !_standInApi,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
