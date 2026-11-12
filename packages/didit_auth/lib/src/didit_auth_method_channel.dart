import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'didit_auth_platform.dart';
import 'errors.dart';

/// [DiditAuthPlatform] over the `didit_auth` method channel.
///
/// Every native failure leaves this class as a [DiditAuthException], and a
/// platform without the native module as a [DiditAuthUnavailableException].
class MethodChannelDiditAuth extends DiditAuthPlatform {
  /// The channel the Android and iOS plugins listen on.
  @visibleForTesting
  final MethodChannel methodChannel = const MethodChannel('didit_auth');

  Future<T?> _invoke<T>(
    String method,
    String publishableKey,
    String redirectUri, [
    Map<String, Object?> arguments = const {},
  ]) async {
    try {
      return await methodChannel.invokeMethod<T>(method, {
        'publishableKey': publishableKey,
        'redirectUri': redirectUri,
        ...arguments,
      });
    } on PlatformException catch (error) {
      throw DiditAuthException.fromPlatformException(error);
    } on MissingPluginException {
      throw const DiditAuthUnavailableException();
    }
  }

  Future<String> _required(Future<String?> call, String method) async {
    final value = await call;
    if (value != null) return value;
    throw DiditAuthException(
      DiditAuthErrorCodes.serverError,
      message: 'The native module returned nothing for $method.',
    );
  }

  @override
  Future<String> signIn(String publishableKey, String redirectUri) => _required(
    _invoke<String>('signIn', publishableKey, redirectUri),
    'signIn',
  );

  @override
  Future<String> signInWithPasskey(String publishableKey, String redirectUri) =>
      _required(
        _invoke<String>('signInWithPasskey', publishableKey, redirectUri),
        'signInWithPasskey',
      );

  @override
  Future<String> registerPasskey(String publishableKey, String redirectUri) =>
      _required(
        _invoke<String>('registerPasskey', publishableKey, redirectUri),
        'registerPasskey',
      );

  @override
  Future<String?> currentSession(
    String publishableKey,
    String redirectUri, {
    required bool force,
  }) => _invoke<String>('currentSession', publishableKey, redirectUri, {
    'force': force,
  });

  @override
  Future<String?> getToken(String publishableKey, String redirectUri) =>
      _invoke<String>('getToken', publishableKey, redirectUri);

  @override
  Future<void> signOut(String publishableKey, String redirectUri) =>
      _invoke<void>('signOut', publishableKey, redirectUri);

  @override
  Future<String> reauthenticate(
    String publishableKey,
    String redirectUri, {
    required String method,
  }) => _required(
    _invoke<String>('reauthenticate', publishableKey, redirectUri, {
      'method': method,
    }),
    'reauthenticate',
  );

  @override
  Future<String> stepUp(
    String publishableKey,
    String redirectUri, {
    required String action,
    String? amount,
    String? currency,
  }) => _required(
    _invoke<String>('stepUp', publishableKey, redirectUri, {
      'action': action,
      'amount': ?amount,
      'currency': ?currency,
    }),
    'stepUp',
  );
}
