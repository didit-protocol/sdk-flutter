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
  retryBlocked,
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
      case 'retryBlocked':
        return VerificationErrorType.retryBlocked;
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

/// Which physical camera lens to use for a capture step.
///
/// Used by [DiditConfig.defaultDocumentCamera] and
/// [DiditConfig.defaultLivenessCamera]. The native SDK falls back to whichever
/// camera is available when the requested lens is not present on the device
/// (for example a tablet with no front camera).
enum CameraLens {
  front,
  back;

  String toMap() => switch (this) {
        CameraLens.front => 'front',
        CameraLens.back => 'back',
      };
}

/// Configuration options for the Didit verification SDK.
///
/// Mirrors the native Android `me.didit.sdk.Configuration` and iOS
/// `DiditSdk.Configuration` so Flutter consumers reach the same surface as
/// the native integrations. All fields are optional with sensible defaults
/// matching the native SDKs.
class DiditConfig {
  /// ISO 639-1 language code for the SDK UI (e.g. "en", "fr", "ar").
  final String? languageCode;

  /// Custom font family name to use throughout the SDK UI.
  final String? fontFamily;

  /// Enable SDK debug logging.
  final bool loggingEnabled;

  /// Show the close (X) button on verification step screens.
  /// Default is `true`.
  final bool showCloseButton;

  /// Show a confirmation dialog when the user attempts to exit.
  /// Default is `true`.
  final bool showExitConfirmation;

  /// Automatically dismiss the verification UI when complete.
  /// Default is `false`.
  final bool closeOnComplete;

  /// Lens used when first entering the document capture screen.
  /// `null` keeps the native default (back camera). Falls back to the first
  /// available camera when the requested lens isn't present on the device.
  final CameraLens? defaultDocumentCamera;

  /// Lens used when first entering the liveness (passive face) capture
  /// screen. `null` keeps the native default (front camera). Falls back to
  /// the first available camera when the requested lens isn't present on the
  /// device.
  final CameraLens? defaultLivenessCamera;

  /// Show the in-capture camera switcher on the document capture screen.
  /// Set to `false` to lock the user to [defaultDocumentCamera]. The switcher
  /// is also automatically hidden on single-camera devices, regardless of
  /// this flag. Default is `true`.
  final bool showDocumentCameraSwitchButton;

  /// Show the in-capture camera switcher on the liveness (passive face)
  /// capture screen. Set to `false` to lock the user to
  /// [defaultLivenessCamera]. The switcher is also automatically hidden on
  /// single-camera devices, regardless of this flag. Default is `true`.
  final bool showLivenessCameraSwitchButton;

  const DiditConfig({
    this.languageCode,
    this.fontFamily,
    this.loggingEnabled = false,
    this.showCloseButton = true,
    this.showExitConfirmation = true,
    this.closeOnComplete = false,
    this.defaultDocumentCamera,
    this.defaultLivenessCamera,
    this.showDocumentCameraSwitchButton = true,
    this.showLivenessCameraSwitchButton = true,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{};
    if (languageCode != null) map['languageCode'] = languageCode;
    if (fontFamily != null) map['fontFamily'] = fontFamily;
    map['loggingEnabled'] = loggingEnabled;
    map['showCloseButton'] = showCloseButton;
    map['showExitConfirmation'] = showExitConfirmation;
    map['closeOnComplete'] = closeOnComplete;
    if (defaultDocumentCamera != null) {
      map['defaultDocumentCamera'] = defaultDocumentCamera!.toMap();
    }
    if (defaultLivenessCamera != null) {
      map['defaultLivenessCamera'] = defaultLivenessCamera!.toMap();
    }
    map['showDocumentCameraSwitchButton'] = showDocumentCameraSwitchButton;
    map['showLivenessCameraSwitchButton'] = showLivenessCameraSwitchButton;
    return map;
  }
}

