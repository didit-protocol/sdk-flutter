library didit_sdk;

import 'sdk_flutter_platform_interface.dart';
import 'src/types.dart';

export 'src/types.dart';

/// Didit Identity Verification SDK for Flutter.
///
/// Provides two methods to start verification:
/// - [startVerification] — with an existing session token from your backend
/// - [startVerificationWithWorkflow] — with a workflow ID (SDK creates the session)
class DiditSdk {
  /// Start identity verification with an existing session token.
  ///
  /// This launches the native Didit verification UI as a full-screen modal.
  /// The returned future completes when the user finishes, cancels, or
  /// encounters an error during the verification flow.
  ///
  /// Example:
  /// ```dart
  /// final result = await DiditSdk.startVerification('session-token');
  /// if (result is VerificationCompleted) {
  ///   print('Status: ${result.session.status}');
  /// }
  /// ```
  static Future<VerificationResult> startVerification(
    String token, {
    DiditConfig? config,
  }) async {
    final raw = await SdkFlutterPlatform.instance.startVerification(
      token,
      config?.toMap(),
    );
    return VerificationResult.fromMap(raw);
  }

  /// Start identity verification by creating a new session with a workflow ID.
  ///
  /// This creates a verification session on the Didit backend, then launches
  /// the native verification UI.
  ///
  /// Example:
  /// ```dart
  /// final result = await DiditSdk.startVerificationWithWorkflow(
  ///   'workflow-id',
  ///   vendorData: 'user-123',
  ///   config: DiditConfig(loggingEnabled: true),
  /// );
  /// ```
  static Future<VerificationResult> startVerificationWithWorkflow(
    String workflowId, {
    String? vendorData,
    String? metadata,
    ContactDetails? contactDetails,
    ExpectedDetails? expectedDetails,
    DiditConfig? config,
  }) async {
    final raw =
        await SdkFlutterPlatform.instance.startVerificationWithWorkflow(
      workflowId,
      vendorData,
      metadata,
      contactDetails?.toMap(),
      expectedDetails?.toMap(),
      config?.toMap(),
    );
    return VerificationResult.fromMap(raw);
  }
}
