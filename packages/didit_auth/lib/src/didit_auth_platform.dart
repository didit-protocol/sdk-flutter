import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'didit_auth_method_channel.dart';

/// The platform side of `DiditAuth`.
///
/// Sessions and step-up results cross the platform boundary as JSON text, so
/// that nulls and nested values arrive unchanged on both platforms.
abstract class DiditAuthPlatform extends PlatformInterface {
  /// Creates a platform implementation.
  DiditAuthPlatform() : super(token: _token);

  static final Object _token = Object();

  static DiditAuthPlatform _instance = MethodChannelDiditAuth();

  /// The implementation in use. Defaults to [MethodChannelDiditAuth].
  static DiditAuthPlatform get instance => _instance;

  /// Replaces the implementation in use, for example with a fake in tests.
  static set instance(DiditAuthPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Signs the person up or in on the hosted page; returns a session as JSON.
  Future<String> signIn(String publishableKey, String redirectUri) {
    throw UnimplementedError('signIn() has not been implemented.');
  }

  /// Signs the person in with a passkey; returns a session as JSON.
  Future<String> signInWithPasskey(String publishableKey, String redirectUri) {
    throw UnimplementedError('signInWithPasskey() has not been implemented.');
  }

  /// Adds a passkey to the signed-in person; returns its id.
  Future<String> registerPasskey(String publishableKey, String redirectUri) {
    throw UnimplementedError('registerPasskey() has not been implemented.');
  }

  /// The signed-in person as JSON, or null.
  Future<String?> currentSession(
    String publishableKey,
    String redirectUri, {
    required bool force,
  }) {
    throw UnimplementedError('currentSession() has not been implemented.');
  }

  /// A valid access token, or null when signed out.
  Future<String?> getToken(String publishableKey, String redirectUri) {
    throw UnimplementedError('getToken() has not been implemented.');
  }

  /// Signs the person out on this device.
  Future<void> signOut(String publishableKey, String redirectUri) {
    throw UnimplementedError('signOut() has not been implemented.');
  }

  /// Runs a step-up; returns its result as JSON.
  Future<String> stepUp(
    String publishableKey,
    String redirectUri, {
    required String action,
    String? amount,
    String? currency,
  }) {
    throw UnimplementedError('stepUp() has not been implemented.');
  }
}
