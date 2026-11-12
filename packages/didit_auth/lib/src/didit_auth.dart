import 'dart:convert';

import 'didit_auth_platform.dart';
import 'errors.dart';
import 'models.dart';

/// Didit Authentication for your app's end users, on the native DiditAuth
/// modules: the hosted sign-in page with PKCE, passkeys, sessions kept in the
/// Keychain or Android Keystore, sign-out and step-ups.
///
/// Create one per application and reuse it. Every call throws a
/// [DiditAuthException] on failure.
///
/// ```dart
/// final auth = DiditAuth(
///   publishableKey: 'pk_live_...',
///   redirectUri: 'https://app.example.com/didit/callback',
/// );
/// final session = await auth.signIn();
/// ```
class DiditAuth {
  /// Creates the client for one application.
  ///
  /// [publishableKey] is the application's key (`pk_live_...` or
  /// `pk_test_...`) from the Didit console. [redirectUri] is the HTTPS
  /// address registered as a redirect URI in the Didit console, and an App
  /// Link (Android) and associated domain (iOS) of your app. Didit accepts no
  /// custom URL schemes. Both are checked by the native module on first use.
  const DiditAuth({required this.publishableKey, required this.redirectUri});

  /// The application's publishable key.
  final String publishableKey;

  /// The HTTPS redirect address of your app.
  final String redirectUri;

  DiditAuthPlatform get _platform => DiditAuthPlatform.instance;

  /// Signs the person up or in on the application's hosted Didit page.
  ///
  /// Throws a [DiditAuthException] with code `cancelled` when the person
  /// closes the page.
  Future<DiditSession> signIn() async => DiditSession.fromJson(
    _object(await _platform.signIn(publishableKey, redirectUri)),
  );

  /// Signs the person in with a passkey of this device.
  ///
  /// Throws `passkey_cancelled` when the person dismisses the prompt and
  /// `passkey_unavailable` when the device cannot run a passkey for this app.
  Future<DiditSession> signInWithPasskey() async => DiditSession.fromJson(
    _object(await _platform.signInWithPasskey(publishableKey, redirectUri)),
  );

  /// Adds a passkey of this device to the signed-in person and returns its
  /// id.
  ///
  /// Needs a session at most five minutes old; otherwise it throws
  /// `reauthentication_required`.
  Future<String> registerPasskey() =>
      _platform.registerPasskey(publishableKey, redirectUri);

  /// The signed-in person, or null when nobody is signed in.
  ///
  /// Answers are reused for 30 seconds; pass [force] before a decision that
  /// must see a revocation immediately.
  Future<DiditSession?> currentSession({bool force = false}) async {
    final json = await _platform.currentSession(
      publishableKey,
      redirectUri,
      force: force,
    );
    return json == null ? null : DiditSession.fromJson(_object(json));
  }

  /// A five-minute access token for your backend, renewed when needed; null
  /// when signed out.
  ///
  /// Verify it on your backend against the issuer's JWKS. Refresh tokens stay
  /// in native storage and never reach Dart.
  Future<String?> getToken() => _platform.getToken(publishableKey, redirectUri);

  /// Signs the person out on this device, and ends the session at Didit when
  /// it can be reached.
  Future<void> signOut() => _platform.signOut(publishableKey, redirectUri);

  /// Runs the identity check a step-up rule asks for before [action], and
  /// returns what Didit recorded.
  ///
  /// Before acting, read the outcome on your backend with
  /// `GET step-up/{id}/` - see [DiditStepUpResult].
  Future<DiditStepUpResult> stepUp(DiditStepUpAction action) async {
    final json = await switch (action) {
      DiditPayoutStepUp(:final amount, :final currency) => _platform.stepUp(
        publishableKey,
        redirectUri,
        action: 'payout',
        amount: amount,
        currency: currency,
      ),
      DiditBankStepUp() => _platform.stepUp(
        publishableKey,
        redirectUri,
        action: 'bank',
      ),
      DiditContactStepUp() => _platform.stepUp(
        publishableKey,
        redirectUri,
        action: 'contact',
      ),
    };
    return DiditStepUpResult.fromJson(_object(json));
  }
}

Map<String, Object?> _object(String json) {
  try {
    final decoded = jsonDecode(json);
    if (decoded is Map<String, dynamic>) {
      return Map<String, Object?>.from(decoded);
    }
  } on FormatException {
    // Falls through to the error below.
  }
  throw const DiditAuthException(
    DiditAuthErrorCodes.serverError,
    message: 'Unexpected answer from the native module.',
  );
}
