import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:didit_sdk_example/main.dart';

void main() {
  testWidgets('Start Verification sends the configured language', (tester) async {
    Map? sent;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('didit_sdk'),
      (call) async {
        sent = call.arguments as Map;
        return {'type': 'completed', 'sessionId': 'manual-session', 'status': 'Declined'};
      },
    );
    await tester.pumpWidget(const MyApp());
    await tester.tap(find.text('Start Verification'));
    await tester.pumpAndSettle();
    // ignore: avoid_print
    print('config sent to native: ${sent?['config']}');
    expect(find.textContaining('Status: declined'), findsOneWidget);
  });
}
