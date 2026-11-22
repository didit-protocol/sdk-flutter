import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'sdk_flutter_platform_interface.dart';
import 'src/bank_link.dart';
import 'src/transactions.dart';
import 'src/types.dart';

export 'src/bank_link.dart';
export 'src/transactions.dart';
export 'src/types.dart';

/// Didit Identity Verification SDK for Flutter.
///
/// Provides two methods to start verification:
/// - [startVerification] — with an existing session token from your backend
/// - [startVerificationWithWorkflow] — with a workflow ID (SDK creates the session)
///
/// And the Bank Link wrapper over the native Bank Link flow:
/// - [presentBankLink] — open a link with the link's `client_token`
/// - [resumeBankLink] — pick the link up after the app was closed at the bank
/// - [bankLinkEvents] — the flow's events, identical to native and web
///
/// And two methods to submit and read transactions from the device:
/// - [submitTransaction] — with a transaction SDK token from your backend
/// - [getTransaction] — fetch a submitted transaction's current state
class DiditSdk {
  /// One verification at a time.
  ///
  /// A verification owns the screen until its native presentation goes away, so
  /// a second one started meanwhile behaves differently on each platform: the
  /// Android plugin opens a second verification UI, and on iOS the new
  /// presentation supersedes the first one, whose Dart future then never
  /// settles. Callers reach this by calling twice, for example on a double tap.
  static _ActiveVerification? _activeVerification;

  static VerificationResult _verificationAlreadyInProgress() =>
      const VerificationFailed(
        error: VerificationError(
          type: VerificationErrorType.unknown,
          message: 'A verification is already in progress.',
        ),
      );

  /// Identifies the verification a call would start, so a repeat of the same
  /// call can join it while anything else is rejected.
  ///
  /// The config map is flattened in a fixed key order: the same options passed
  /// in a different order must not read as a different verification.
  static String _verificationKey(
    String kind,
    List<String?> identity,
    Map<String, dynamic> config,
  ) {
    final sortedConfig = <String, dynamic>{
      for (final key in config.keys.toList()..sort()) key: config[key],
    };
    return jsonEncode([kind, ...identity, sortedConfig]);
  }

  /// Runs [start] as the one verification in flight.
  ///
  /// An identical repeat call returns the running verification's own future, so
  /// every caller gets the same result. A different call resolves as failed
  /// without reaching the platform. The guard is released as soon as [start]
  /// settles, including when it throws or its future fails.
  ///
  /// Not `async`: the guard has to be in place before the first call returns to
  /// its caller, or two calls in the same event-loop turn both pass the check.
  static Future<VerificationResult> _startExclusively(
    String key,
    Future<Map<String, dynamic>> Function() start,
  ) {
    final inFlight = _activeVerification;
    if (inFlight != null) {
      return inFlight.key == key
          ? inFlight.result
          : Future<VerificationResult>.value(_verificationAlreadyInProgress());
    }

    final entry = _ActiveVerification(
      key,
      Future<Map<String, dynamic>>.sync(start).then(VerificationResult.fromMap),
    );
    _activeVerification = entry;
    void release() {
      if (identical(_activeVerification, entry)) _activeVerification = null;
    }

    entry.result.then((_) => release(), onError: (_) => release());
    return entry.result;
  }

  static Map<String, dynamic> _verificationConfig(DiditConfig? config) {
    final resolvedConfig = config?.toMap() ?? <String, dynamic>{};
    resolvedConfig.putIfAbsent('languageCode', _deviceLanguageCode);
    return resolvedConfig;
  }

  /// The device locale as the native SDK names it.
  ///
  /// The native SDKs distinguish Simplified and Traditional Chinese and
  /// Brazilian Portuguese with their own codes, so the two-letter language
  /// alone would send those users to the generic variant.
  static String _deviceLanguageCode() {
    final locale = WidgetsBinding.instance.platformDispatcher.locale;
    final country = locale.countryCode?.toUpperCase();
    final script = locale.scriptCode?.toLowerCase();

    switch (locale.languageCode) {
      case 'zh':
        if (script == 'hant' ||
            country == 'TW' ||
            country == 'HK' ||
            country == 'MO') {
          return 'zh-TW';
        }
        if (script == 'hans' || country == 'CN' || country == 'SG') {
          return 'zh-CN';
        }
        return 'zh';
      case 'pt':
        return country == 'BR' ? 'pt-BR' : 'pt';
      default:
        return locale.languageCode;
    }
  }

  /// Start identity verification with an existing session token.
  ///
  /// This launches the native Didit verification UI as a full-screen modal.
  /// The returned future completes when the user finishes, cancels, or
  /// encounters an error during the verification flow.
  ///
  /// While a verification is running, calling this again with the same token
  /// and config returns that verification's future; calling it with anything
  /// else resolves [VerificationFailed] with "A verification is already in
  /// progress." without starting a second verification.
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
  }) {
    final resolvedConfig = _verificationConfig(config);
    return _startExclusively(
      _verificationKey('token', [token], resolvedConfig),
      () =>
          SdkFlutterPlatform.instance.startVerification(token, resolvedConfig),
    );
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
  ///
  /// While a verification is running, calling this again with the same
  /// workflow, vendor data and config returns that verification's future;
  /// calling it with anything else resolves [VerificationFailed] with "A
  /// verification is already in progress." without starting a second one.
  static Future<VerificationResult> startVerificationWithWorkflow(
    String workflowId, {
    String? vendorData,
    DiditConfig? config,
  }) {
    final resolvedConfig = _verificationConfig(config);
    return _startExclusively(
      _verificationKey('workflow', [workflowId, vendorData], resolvedConfig),
      () => SdkFlutterPlatform.instance.startVerificationWithWorkflow(
        workflowId,
        vendorData,
        resolvedConfig,
      ),
    );
  }

  /// The Bank Link in flight, if any: a link owns the screen until its native
  /// presentation goes away, exactly like a verification.
  static Future<BankLinkResult>? _activeBankLink;

  static BankLinkResult _bankLinkAlreadyInProgress() => const BankLinkExit(
    reason: BankLinkExitReason.failed,
    resumed: false,
  );

  /// Open a Bank Link.
  ///
  /// [token] is the link's `client_token` (`blt_...`) from the customer's
  /// backend; the API key never reaches the app. Everything the person sees is
  /// native UI: the wrapper adds no screen, no copy and no language of its own.
  ///
  /// The future settles once with a [BankLinkSuccess] or a [BankLinkExit]; a
  /// bridge failure settles it as [BankLinkExitReason.failed], never as an
  /// exception. Calling it again while a link is open resolves the same way
  /// without opening a second link.
  ///
  /// Example:
  /// ```dart
  /// final result = await DiditSdk.presentBankLink(clientToken);
  /// if (result is BankLinkSuccess) {
  ///   print('Connected: ${result.connectionId}');
  /// }
  /// ```
  static Future<BankLinkResult> presentBankLink(
    String token, {
    BankLinkOptions? options,
  }) {
    if (_activeBankLink != null) {
      return Future<BankLinkResult>.value(_bankLinkAlreadyInProgress());
    }

    final config = _verificationConfig(options?.config);
    final result = Future<Map<String, dynamic>>.sync(
      () => SdkFlutterPlatform.instance.presentBankLink(token, {
        'config': config,
      }),
    ).then<BankLinkResult>(
      BankLinkResult.fromMap,
      onError: (Object _) => _bankLinkAlreadyInProgress(),
    );
    _activeBankLink = result;
    void release() {
      if (identical(_activeBankLink, result)) _activeBankLink = null;
    }

    result.then((_) => release(), onError: (_) => release());
    return result;
  }

  /// Pick up a link whose bank trip outlived the app.
  ///
  /// Call it from the host's startup and from its app-link handler: the native
  /// SDK restores the step the person was on, and the result comes back with
  /// `resumed: true`. `null` when there is nothing to resume, which is also
  /// what a bridge that cannot answer says, so a host never has to special-case
  /// an SDK version without Bank Link.
  static Future<BankLinkResult?> resumeBankLink() async {
    try {
      final raw = await SdkFlutterPlatform.instance.resumeBankLink();
      return raw == null ? null : BankLinkResult.fromMap(raw);
    } on Exception {
      return null;
    }
  }

  /// Hand the SDK an address the app was opened with, for hosts whose bank
  /// return is an app link or universal link handled by the app itself.
  ///
  /// `true` when the address was a Bank Link return. The address is passed on
  /// unchanged: a resume code carries a dot and arrives in a query parameter,
  /// so nothing here splits or validates it.
  static Future<bool> handleBankLinkReturn(String url) async {
    try {
      return await SdkFlutterPlatform.instance.handleBankLinkReturn(url);
    } on Exception {
      return false;
    }
  }

  /// The events of the running link, identical to native and web.
  ///
  /// Each event carries ids only (`link_id`, `institution_id`,
  /// `consent_version`, ...). `success` and `exit` also reach this stream, next
  /// to settling the [presentBankLink] future.
  static Stream<BankLinkEvent> get bankLinkEvents =>
      SdkFlutterPlatform.instance.bankLinkEvents;

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
      final raw = await SdkFlutterPlatform.instance
          .submitTransaction(transactionToken, transaction.toMap(), {
            'callId': callId,
            'autoLaunchAction': options.autoLaunchAction,
            if (options.baseUrl != null) 'baseUrl': options.baseUrl,
          });
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

class _ActiveVerification {
  const _ActiveVerification(this.key, this.result);

  final String key;
  final Future<VerificationResult> result;
}
