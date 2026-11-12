import 'errors.dart';

/// An organization the signed-in person belongs to.
class DiditOrganization {
  /// Creates an organization.
  const DiditOrganization({
    required this.id,
    required this.name,
    required this.role,
  });

  /// Parses the native module's JSON object.
  factory DiditOrganization.fromJson(Map<String, Object?> json) =>
      DiditOrganization(
        id: _string(json, 'id'),
        name: _string(json, 'name'),
        role: _string(json, 'role'),
      );

  /// The organization's id.
  final String id;

  /// The organization's name.
  final String name;

  /// The person's role in the organization.
  final String role;

  @override
  bool operator ==(Object other) =>
      other is DiditOrganization &&
      other.id == id &&
      other.name == name &&
      other.role == role;

  @override
  int get hashCode => Object.hash(id, name, role);
}

/// The signed-in person, as Didit reports their session.
class DiditSession {
  /// Creates a session.
  const DiditSession({
    required this.userId,
    required this.sessionId,
    required this.applicationId,
    required this.emailVerified,
    required this.methods,
    required this.mfaVerified,
    required this.organizations,
    required this.expiresAt,
    this.vendorData,
    this.email,
    this.phone,
    this.verified,
  });

  /// Parses the native module's JSON object.
  ///
  /// Throws a [DiditAuthException] with code `server_error` when a field is
  /// missing or has the wrong type.
  factory DiditSession.fromJson(Map<String, Object?> json) => DiditSession(
    userId: _string(json, 'userId'),
    sessionId: _string(json, 'sessionId'),
    applicationId: _string(json, 'applicationId'),
    vendorData: _optionalString(json, 'vendorData'),
    email: _optionalString(json, 'email'),
    emailVerified: _bool(json, 'emailVerified'),
    phone: _optionalString(json, 'phone'),
    methods: _stringList(json, 'methods'),
    mfaVerified: _bool(json, 'mfaVerified'),
    verified: _optionalObject(json, 'verified'),
    organizations: [
      for (final item in _list(json, 'organizations'))
        DiditOrganization.fromJson(_asObject(item, 'organizations')),
    ],
    expiresAt: _dateTime(json, 'expiresAt'),
  );

  /// The person's Didit identity id (`sub`).
  final String userId;

  /// The id of this session.
  final String sessionId;

  /// The id of the application the person signed in to.
  final String applicationId;

  /// Your id for the person: ties them to their verifications and
  /// transactions.
  final String? vendorData;

  /// The person's email address, when they gave one.
  final String? email;

  /// Whether [email] is verified.
  final bool emailVerified;

  /// The person's phone number, when they gave one.
  final String? phone;

  /// How the session was created, for example `['password']` or
  /// `['passkey']`.
  final List<String> methods;

  /// Whether the person passed multi-factor authentication.
  final bool mfaVerified;

  /// The verified identity level and the claims your application selected,
  /// or null.
  final Map<String, Object?>? verified;

  /// The organizations the person belongs to.
  final List<DiditOrganization> organizations;

  /// When the session ends.
  final DateTime expiresAt;
}

/// A sensitive action your application's step-up rules can apply to.
sealed class DiditStepUpAction {
  const DiditStepUpAction();
}

/// A payout.
final class DiditPayoutStepUp extends DiditStepUpAction {
  /// Creates a payout action. [amount] is a decimal string such as
  /// `'900.00'` and [currency] an ISO 4217 code.
  const DiditPayoutStepUp({required this.amount, this.currency});

  /// The amount as a decimal string such as `'900.00'`.
  final String amount;

  /// The ISO 4217 currency code, for example `'EUR'`.
  final String? currency;
}

/// Adding or changing a bank account.
final class DiditBankStepUp extends DiditStepUpAction {
  /// Creates a bank account action.
  const DiditBankStepUp();
}

/// Changing the email address or phone number.
final class DiditContactStepUp extends DiditStepUpAction {
  /// Creates a contact change action.
  const DiditContactStepUp();
}

/// What came of a step-up.
///
/// Before acting, your backend reads the outcome itself with
/// `GET step-up/{id}/`: an app can be tampered with, Didit's record cannot.
class DiditStepUpResult {
  /// Creates a step-up result.
  const DiditStepUpResult({
    required this.status,
    required this.approved,
    this.id,
    this.rule,
    this.method,
  });

  /// Parses the native module's JSON object.
  ///
  /// Throws a [DiditAuthException] with code `server_error` when a field is
  /// missing or has the wrong type.
  factory DiditStepUpResult.fromJson(Map<String, Object?> json) =>
      DiditStepUpResult(
        id: _optionalString(json, 'id'),
        status: _string(json, 'status'),
        approved: _bool(json, 'approved'),
        rule: _optionalString(json, 'rule'),
        method: _optionalString(json, 'method'),
      );

  /// The step-up's id; null when no rule asked for one.
  final String? id;

  /// `not_required`, `approved`, `pending`, `review`, `declined` or
  /// `expired`.
  final String status;

  /// The action may go ahead: no step-up was needed, or the person passed it.
  final bool approved;

  /// The rule that asked for it, for example `payout` or `device`.
  final String? rule;

  /// `liveness`, `selfie` or `full_id`.
  final String? method;

  @override
  bool operator ==(Object other) =>
      other is DiditStepUpResult &&
      other.id == id &&
      other.status == status &&
      other.approved == approved &&
      other.rule == rule &&
      other.method == method;

  @override
  int get hashCode => Object.hash(id, status, approved, rule, method);
}

DiditAuthException _malformed(String key) => DiditAuthException(
  DiditAuthErrorCodes.serverError,
  message: 'Unexpected answer from the native module: "$key".',
);

String _string(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is String) return value;
  throw _malformed(key);
}

String? _optionalString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null || value is String) return value as String?;
  throw _malformed(key);
}

bool _bool(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is bool) return value;
  throw _malformed(key);
}

DateTime _dateTime(Map<String, Object?> json, String key) {
  final parsed = DateTime.tryParse(_string(json, key));
  if (parsed != null) return parsed;
  throw _malformed(key);
}

List<Object?> _list(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is List) return List<Object?>.from(value);
  throw _malformed(key);
}

List<String> _stringList(Map<String, Object?> json, String key) {
  final items = _list(json, key);
  if (items.every((item) => item is String)) return List<String>.from(items);
  throw _malformed(key);
}

Map<String, Object?> _asObject(Object? value, String key) {
  if (value is Map && value.keys.every((k) => k is String)) {
    return Map<String, Object?>.from(value);
  }
  throw _malformed(key);
}

Map<String, Object?>? _optionalObject(Map<String, Object?> json, String key) {
  final value = json[key];
  return value == null ? null : _asObject(value, key);
}
