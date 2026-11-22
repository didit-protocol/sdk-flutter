import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'sdk_flutter_platform_interface.dart';
import 'src/bank_link.dart';

/// MethodChannel implementation of [SdkFlutterPlatform].
class MethodChannelSdkFlutter extends SdkFlutterPlatform {
  @visibleForTesting
  final methodChannel = const MethodChannel('didit_sdk');

  @visibleForTesting
  final bankLinkEventChannel = const EventChannel('didit_sdk/bank_link_events');

  Stream<BankLinkEvent>? _bankLinkEvents;

  void Function(String callId, Map<String, dynamic> result)?
  _transactionUpdateHandler;

  @override
  Future<Map<String, dynamic>> startVerification(
    String token,
    Map<String, dynamic>? config,
  ) async {
    final result = await methodChannel.invokeMethod<Map>('startVerification', {
      'token': token,
      'config': ?config,
    });
    return Map<String, dynamic>.from(result ?? {});
  }

  @override
  Future<Map<String, dynamic>> startVerificationWithWorkflow(
    String workflowId,
    String? vendorData,
    Map<String, dynamic>? config,
  ) async {
    final result = await methodChannel.invokeMethod<Map>(
      'startVerificationWithWorkflow',
      {'workflowId': workflowId, 'vendorData': ?vendorData, 'config': ?config},
    );
    return Map<String, dynamic>.from(result ?? {});
  }

  @override
  Future<Map<String, dynamic>> submitTransaction(
    String transactionToken,
    Map<String, dynamic> transaction,
    Map<String, dynamic> options,
  ) async {
    final result = await methodChannel.invokeMethod<Map>('submitTransaction', {
      'transactionToken': transactionToken,
      'transaction': transaction,
      'options': options,
    });
    return Map<String, dynamic>.from(result ?? {});
  }

  @override
  Future<Map<String, dynamic>> getTransaction(
    String transactionToken,
    String transactionId,
    Map<String, dynamic> options,
  ) async {
    final result = await methodChannel.invokeMethod<Map>('getTransaction', {
      'transactionToken': transactionToken,
      'transactionId': transactionId,
      'options': options,
    });
    return Map<String, dynamic>.from(result ?? {});
  }

  @override
  Future<Map<String, dynamic>> presentBankLink(
    String token,
    Map<String, dynamic> options,
  ) async {
    final result = await methodChannel.invokeMethod<Map>('presentBankLink', {
      'token': token,
      'options': options,
    });
    return Map<String, dynamic>.from(result ?? {});
  }

  @override
  Future<Map<String, dynamic>?> resumeBankLink() async {
    final result = await methodChannel.invokeMethod<Map>('resumeBankLink');
    return result == null ? null : Map<String, dynamic>.from(result);
  }

  @override
  Future<bool> handleBankLinkReturn(String url) async {
    final handled = await methodChannel.invokeMethod<bool>(
      'handleBankLinkReturn',
      {'url': url},
    );
    return handled ?? false;
  }

  /// One broadcast subscription for the whole app: the native side opens its
  /// event sink on the first listen and keeps it for later listeners.
  @override
  Stream<BankLinkEvent> get bankLinkEvents =>
      _bankLinkEvents ??= bankLinkEventChannel
          .receiveBroadcastStream()
          .map(BankLinkEvent.fromChannel);

  @override
  void setTransactionUpdateHandler(
    void Function(String callId, Map<String, dynamic> result)? handler,
  ) {
    _transactionUpdateHandler = handler;
    methodChannel.setMethodCallHandler(
      handler == null ? null : _handlePlatformCall,
    );
  }

  Future<dynamic> _handlePlatformCall(MethodCall call) async {
    if (call.method == 'onTransactionUpdated') {
      final arguments = Map<String, dynamic>.from(call.arguments as Map);
      final result = arguments['result'];
      _transactionUpdateHandler?.call(
        arguments['callId'] as String? ?? '',
        result is Map ? Map<String, dynamic>.from(result) : {},
      );
    }
    return null;
  }
}
