import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'sdk_flutter_method_channel.dart';
import 'src/bank_link.dart';

abstract class SdkFlutterPlatform extends PlatformInterface {
  SdkFlutterPlatform() : super(token: _token);

  static final Object _token = Object();

  static SdkFlutterPlatform _instance = MethodChannelSdkFlutter();

  static SdkFlutterPlatform get instance => _instance;

  static set instance(SdkFlutterPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Start verification with an existing session token.
  Future<Map<String, dynamic>> startVerification(
    String token,
    Map<String, dynamic>? config,
  ) {
    throw UnimplementedError('startVerification() has not been implemented.');
  }

  /// Start verification by creating a session with a workflow ID.
  Future<Map<String, dynamic>> startVerificationWithWorkflow(
    String workflowId,
    String? vendorData,
    Map<String, dynamic>? config,
  ) {
    throw UnimplementedError(
      'startVerificationWithWorkflow() has not been implemented.',
    );
  }

  /// Submit a transaction with a transaction SDK token.
  Future<Map<String, dynamic>> submitTransaction(
    String transactionToken,
    Map<String, dynamic> transaction,
    Map<String, dynamic> options,
  ) {
    throw UnimplementedError('submitTransaction() has not been implemented.');
  }

  /// Fetch a transaction previously submitted with the same token.
  Future<Map<String, dynamic>> getTransaction(
    String transactionToken,
    String transactionId,
    Map<String, dynamic> options,
  ) {
    throw UnimplementedError('getTransaction() has not been implemented.');
  }

  /// Open a Bank Link from the link's client token (`blt_...`).
  ///
  /// Answers the result map `{'type': 'success', 'linkId': ..., 'resumed':
  /// bool}` or `{'type': 'exit', 'reason': ..., 'step': ..., 'resumed': bool}`.
  Future<Map<String, dynamic>> presentBankLink(
    String token,
    Map<String, dynamic> options,
  ) {
    throw UnimplementedError('presentBankLink() has not been implemented.');
  }

  /// Pick up a link whose bank trip outlived the app.
  ///
  /// `null` when there is nothing to resume.
  ///
  /// [config] is the same configuration map a presentation takes (language,
  /// fonts, logging), so a resumed link looks like the presented one.
  Future<Map<String, dynamic>?> resumeBankLink({Map<String, dynamic>? config}) {
    throw UnimplementedError('resumeBankLink() has not been implemented.');
  }

  /// Hand the platform an address the app was opened with.
  ///
  /// `true` when the address was a Bank Link return.
  Future<bool> handleBankLinkReturn(String url) {
    throw UnimplementedError(
      'handleBankLinkReturn() has not been implemented.',
    );
  }

  /// The events of the running link, as the native SDK emits them.
  Stream<BankLinkEvent> get bankLinkEvents {
    throw UnimplementedError('bankLinkEvents has not been implemented.');
  }

  /// Register the handler invoked when the platform reports a refreshed
  /// transaction after an auto-launched action completes.
  void setTransactionUpdateHandler(
    void Function(String callId, Map<String, dynamic> result)? handler,
  ) {
    throw UnimplementedError(
      'setTransactionUpdateHandler() has not been implemented.',
    );
  }
}
