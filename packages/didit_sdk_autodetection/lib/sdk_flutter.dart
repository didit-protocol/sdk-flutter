import 'package:flutter/services.dart';

import 'sdk_flutter_platform_interface.dart';
import 'src/transactions.dart';
import 'src/types.dart';

export 'src/transactions.dart';
export 'src/types.dart';

/// Didit Identity Verification SDK for Flutter.
///
/// Provides two methods to start verification:
/// - [startVerification] — with an existing session token from your backend
/// - [startVerificationWithWorkflow] — with a workflow ID (SDK creates the session)
///
/// And two methods to submit and read transactions from the device:
/// - [submitTransaction] — with a transaction SDK token from your backend
/// - [getTransaction] — fetch a submitted transaction's current state
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
    DiditConfig? config,
  }) async {
    final raw = await SdkFlutterPlatform.instance.startVerificationWithWorkflow(
      workflowId,
      vendorData,
      config?.toMap(),
    );
    return VerificationResult.fromMap(raw);
  }

  static int _transactionCallCounter = 0;
  static bool _transactionUpdateHandlerRegistered = false;
  static final Map<String, void Function(DiditTransactionResult)>
      _pendingTransactionUpdates = {};

  static void _ensureTransactionUpdateHandler() {
    if (_transactionUpdateHandlerRegistered) return;
    _transactionUpdateHandlerRegistered = true;
    SdkFlutterPlatform.instance.setTransactionUpdateHandler((callId, result) {
      final callback = _pendingTransactionUpdates.remove(callId);
      callback?.call(DiditTransactionResult.fromMap(result));
    });
  }

  /// Submit a transaction directly from the device.
  ///
  /// Requires a transaction SDK token minted by your backend via
  /// `POST /v3/transactions/sdk-token/`. Device intelligence is attached
  /// automatically. If the response requires a wallet-ownership widget and
  /// [DiditTransactionOptions.autoLaunchAction] is not disabled, the SDK
  /// launches it natively and later invokes
  /// [DiditTransactionOptions.onTransactionUpdated] with the refreshed
  /// transaction. A `verification_session` action is never auto-launched —
  /// it is returned on [DiditTransactionResult.actionRequired] for the host
  /// app to launch with its own Didit verification integration.
  ///
  /// Throws a [DiditTransactionException] with [DiditTransactionException.code]
  /// set to `invalid_token`, `expired_token`, `validation` (see
  /// [DiditTransactionException.fieldErrors]), or `network`.
  ///
  /// Example:
  /// ```dart
  /// final result = await DiditSdk.submitTransaction(
  ///   sdkToken,
  ///   DiditTransactionPayload(
  ///     txnId: 'order-123',
  ///     type: 'crypto',
  ///     info: DiditTransactionInfo(
  ///       direction: 'outbound',
  ///       amount: 0.25,
  ///       currency: 'ETH',
  ///     ),
  ///     travelRule: DiditTravelRule(required: true),
  ///   ),
  ///   options: DiditTransactionOptions(
  ///     onTransactionUpdated: (updated) => print(updated.status),
  ///   ),
  /// );
  /// print('${result.transactionId} ${result.actionRequired?.type}');
  /// ```
  static Future<DiditTransactionResult> submitTransaction(
    String transactionToken,
    DiditTransactionPayload transaction, {
    DiditTransactionOptions options = const DiditTransactionOptions(),
  }) async {
    final callId =
        'txn-${DateTime.now().millisecondsSinceEpoch}-${++_transactionCallCounter}';
    final onTransactionUpdated = options.onTransactionUpdated;
    if (options.autoLaunchAction && onTransactionUpdated != null) {
      _ensureTransactionUpdateHandler();
      _pendingTransactionUpdates[callId] = onTransactionUpdated;
    }
    try {
      final raw = await SdkFlutterPlatform.instance.submitTransaction(
        transactionToken,
        transaction.toMap(),
        {
          'callId': callId,
          'autoLaunchAction': options.autoLaunchAction,
          if (options.baseUrl != null) 'baseUrl': options.baseUrl,
        },
      );
      final result = DiditTransactionResult.fromMap(raw);
      if (result.actionRequired == null) {
        _pendingTransactionUpdates.remove(callId);
      }
      return result;
    } on PlatformException catch (e) {
      _pendingTransactionUpdates.remove(callId);
      throw DiditTransactionException.fromPlatformException(e);
    }
  }

  /// Fetch a transaction previously submitted with the same transaction token.
  ///
  /// Throws a [DiditTransactionException] with [DiditTransactionException.code]
  /// set to `invalid_token`, `expired_token`, `validation`, or `network`.
  static Future<DiditTransactionResult> getTransaction(
    String transactionToken,
    String transactionId, {
    DiditTransactionOptions options = const DiditTransactionOptions(),
  }) async {
    try {
      final raw = await SdkFlutterPlatform.instance.getTransaction(
        transactionToken,
        transactionId,
        {if (options.baseUrl != null) 'baseUrl': options.baseUrl},
      );
      return DiditTransactionResult.fromMap(raw);
    } on PlatformException catch (e) {
      throw DiditTransactionException.fromPlatformException(e);
    }
  }
}
