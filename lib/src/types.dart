/// The status of a completed verification session.
enum VerificationStatus {
  /// The user's identity was successfully verified.
  approved,

  /// The verification is still being reviewed.
  pending,

  /// The verification was declined.
  declined;

  static VerificationStatus fromString(String? value) {
    switch (value) {
      case 'Approved':
        return VerificationStatus.approved;
      case 'Declined':
        return VerificationStatus.declined;
      case 'Pending':
      default:
        return VerificationStatus.pending;
    }
  }
}

/// Error type identifiers returned by the native SDK.
enum VerificationErrorType {
  sessionExpired,
  networkError,
  cameraAccessDenied,
  notInitialized,
  apiError,
  unknown;

  static VerificationErrorType fromString(String? value) {
    switch (value) {
      case 'sessionExpired':
        return VerificationErrorType.sessionExpired;
      case 'networkError':
        return VerificationErrorType.networkError;
      case 'cameraAccessDenied':
        return VerificationErrorType.cameraAccessDenied;
      case 'notInitialized':
        return VerificationErrorType.notInitialized;
      case 'apiError':
        return VerificationErrorType.apiError;
      default:
        return VerificationErrorType.unknown;
    }
  }
}

/// Describes an error that occurred during verification.
class VerificationError {
  /// The category of error.
  final VerificationErrorType type;

  /// A human-readable error message.
  final String message;

  const VerificationError({required this.type, required this.message});
}

/// Data about the verification session.
class SessionData {
  /// The unique session identifier.
  final String sessionId;

  /// The verification status.
  final VerificationStatus status;

  const SessionData({required this.sessionId, required this.status});
}

/// Base class for verification results.
sealed class VerificationResult {
  const VerificationResult();

  factory VerificationResult.fromMap(Map<String, dynamic> map) {
    final type = map['type'] as String?;
    final sessionId = map['sessionId'] as String?;
    final status = map['status'] as String?;

    final session = sessionId != null
        ? SessionData(
            sessionId: sessionId,
            status: VerificationStatus.fromString(status),
          )
        : null;

    switch (type) {
      case 'completed':
        if (session == null) {
          return VerificationFailed(
            error: const VerificationError(
              type: VerificationErrorType.unknown,
              message:
                  'Verification completed but no session data was returned.',
            ),
          );
        }
        return VerificationCompleted(session: session);

      case 'cancelled':
        return VerificationCancelled(session: session);

      case 'failed':
        return VerificationFailed(
          error: VerificationError(
            type: VerificationErrorType.fromString(
                map['errorType'] as String?),
            message: (map['errorMessage'] as String?) ??
                'An unknown error occurred during verification.',
          ),
          session: session,
        );

      default:
        return VerificationFailed(
          error: VerificationError(
            type: VerificationErrorType.unknown,
            message: 'Unexpected result type: $type',
          ),
          session: session,
        );
    }
  }
}

/// Returned when the verification flow was completed.
class VerificationCompleted extends VerificationResult {
  final SessionData session;
  const VerificationCompleted({required this.session});
}

/// Returned when the user cancelled the verification flow.
class VerificationCancelled extends VerificationResult {
  final SessionData? session;
  const VerificationCancelled({this.session});
}

/// Returned when the verification failed due to an error.
class VerificationFailed extends VerificationResult {
  final VerificationError error;
  final SessionData? session;
  const VerificationFailed({required this.error, this.session});
}

/// Configuration options for the Didit verification SDK.
class DiditConfig {
  /// ISO 639-1 language code for the SDK UI (e.g. "en", "fr", "ar").
  final String? languageCode;

  /// Custom font family name to use throughout the SDK UI.
  final String? fontFamily;

  /// Enable SDK debug logging.
  final bool loggingEnabled;

  const DiditConfig({
    this.languageCode,
    this.fontFamily,
    this.loggingEnabled = false,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{};
    if (languageCode != null) map['languageCode'] = languageCode;
    if (fontFamily != null) map['fontFamily'] = fontFamily;
    map['loggingEnabled'] = loggingEnabled;
    return map;
  }
}

