import 'package:flutter/services.dart';

/// The stable `code` values of a [DiditAuthException].
///
/// Codes from the Didit API pass through unchanged (for example
/// `invalid_grant`, `method_unavailable` or `reauthentication_required`), so a
/// code may be a string that is not listed here. The native modules add the
/// codes below, and they are the same on Android and iOS and in the React
/// Native package.
abstract final class DiditAuthErrorCodes {
  /// The person closed the sign-in or step-up page.
  static const String cancelled = 'cancelled';

  /// The page returned for a sign-in this app did not start.
  static const String invalidState = 'invalid_state';

  /// The call needs a signed-in person.
  static const String notSignedIn = 'not_signed_in';

  /// A different person than the signed-in one completed a
  /// `DiditAuth.reauthenticate`. The new session is ended at Didit and the
  /// stored session is untouched.
  static const String stepUpUserMismatch = 'step_up_user_mismatch';

  /// The person dismissed the passkey prompt.
  static const String passkeyCancelled = 'passkey_cancelled';

  /// The device cannot run a passkey for this app.
  static const String passkeyUnavailable = 'passkey_unavailable';

  /// The page cannot be shown: no screen of the app is in the foreground, or
  /// iOS is older than 17.4, which the hosted pages need.
  static const String browserUnavailable = 'browser_unavailable';

  /// The Keychain or Android Keystore could not keep the tokens.
  static const String storageUnavailable = 'storage_unavailable';

  /// Too many requests; see [DiditAuthException.retryAfter].
  static const String rateLimited = 'rate_limited';

  /// The publishable key is not valid for this application.
  static const String invalidPublishableKey = 'invalid_publishable_key';

  /// The redirect URI is not a valid HTTPS address, or is not registered.
  static const String invalidRedirectUri = 'invalid_redirect_uri';

  /// The request is malformed, for example a payout step-up without an amount.
  static const String invalidRequest = 'invalid_request';

  /// Didit could not be reached.
  static const String networkError = 'network_error';

  /// Didit answered with a server error or an unexpected answer.
  static const String serverError = 'server_error';

  /// A native failure that is not a DiditAuth error.
  static const String unspecified = 'unspecified';

  /// The plugin is not available on this platform (it runs on Android and
  /// iOS only), or the app was built without it.
  static const String unavailable = 'ERR_DIDIT_AUTH_UNAVAILABLE';
}

/// The one exception every call of `DiditAuth` throws, with the native
/// module's `code` and message unchanged.
class DiditAuthException implements Exception {
  /// Creates an exception with a stable [code].
  const DiditAuthException(
    this.code, {
    String? message,
    this.status,
    this.fields,
    this.retryAfter,
  }) : message = message ?? code;

  /// Maps a native [PlatformException] to a [DiditAuthException].
  ///
  /// The native modules send `status`, `fields` and `retryAfter` in the
  /// exception's details when Didit's answer had them.
  factory DiditAuthException.fromPlatformException(PlatformException error) {
    final details = error.details;
    int? status;
    int? retryAfter;
    Map<String, List<String>>? fields;
    if (details is Map) {
      final rawStatus = details['status'];
      final rawRetryAfter = details['retryAfter'];
      final rawFields = details['fields'];
      status = rawStatus is num ? rawStatus.toInt() : null;
      retryAfter = rawRetryAfter is num ? rawRetryAfter.toInt() : null;
      fields = _fields(rawFields);
    }
    return DiditAuthException(
      error.code,
      message: error.message,
      status: status,
      fields: fields,
      retryAfter: retryAfter,
    );
  }

  /// A stable machine-readable code; see [DiditAuthErrorCodes].
  final String code;

  /// A human-readable description, for logs. Do not show it to people.
  final String message;

  /// HTTP status of Didit's answer, when there was one.
  final int? status;

  /// Per-field codes, for example `{'return_to': ['invalid_redirect_uri']}`.
  final Map<String, List<String>>? fields;

  /// Seconds to wait before trying again, for `rate_limited`.
  final int? retryAfter;

  @override
  String toString() => 'DiditAuthException($code): $message';
}

/// The plugin is not available on this platform; see
/// [DiditAuthErrorCodes.unavailable].
class DiditAuthUnavailableException extends DiditAuthException {
  /// Creates the exception for a platform without the native module.
  const DiditAuthUnavailableException()
    : super(
        DiditAuthErrorCodes.unavailable,
        message: 'DiditAuth is unavailable on this platform.',
      );
}

Map<String, List<String>>? _fields(Object? raw) {
  if (raw is! Map) return null;
  final fields = <String, List<String>>{};
  for (final entry in raw.entries) {
    final codes = entry.value;
    if (entry.key is! String || codes is! List) return null;
    if (codes.any((code) => code is! String)) return null;
    fields[entry.key as String] = List<String>.from(codes);
  }
  return fields;
}
