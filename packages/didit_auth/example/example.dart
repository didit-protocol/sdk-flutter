// ignore_for_file: avoid_print
// Every call of Didit Authentication, in the order an app uses them. Call
// `runAuthFlow` from a button handler of your app; `signIn` and `stepUp` open
// the hosted Didit page, so they need a running app with a screen in the
// foreground.
import 'package:didit_auth/didit_auth.dart';

// One client per application; reuse it.
const auth = DiditAuth(
  publishableKey: 'pk_test_...',
  redirectUri: 'https://app.example.com/didit/callback',
);

Future<void> runAuthFlow() async {
  try {
    // Is somebody already signed in? Null when not.
    var session = await auth.currentSession();

    // Hosted page: sign-up and sign-in. A passkey of this device also works:
    // await auth.signInWithPasskey();
    session ??= await auth.signIn();
    print('Signed in as ${session.userId} until ${session.expiresAt}');

    // Ask the same person to sign in again, for example before adding a
    // passkey. A different person signing in throws step_up_user_mismatch.
    session = await auth.reauthenticate();

    // A five-minute token for your backend, renewed when needed.
    final token = await auth.getToken();
    print(
      'Send ${token?.length ?? 0} characters to your backend as a Bearer token',
    );

    // Before a sensitive action, run the step-up your rules ask for.
    final result = await auth.stepUp(
      const DiditPayoutStepUp(amount: '900.00', currency: 'EUR'),
    );
    if (result.approved) {
      // Your backend confirms with GET step-up/{result.id}/ before it pays out.
    }

    await auth.signOut();
  } on DiditAuthException catch (error) {
    // A person closing the page is not an error.
    if (error.code == DiditAuthErrorCodes.cancelled) return;
    if (error.code == DiditAuthErrorCodes.stepUpUserMismatch) {
      print('A different person signed in; the stored session is unchanged');
      return;
    }
    if (error.code == DiditAuthErrorCodes.rateLimited) {
      print('Try again in ${error.retryAfter} seconds');
      return;
    }
    print('${error.code}: ${error.message}');
  }
}
