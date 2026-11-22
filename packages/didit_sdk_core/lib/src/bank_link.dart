import 'types.dart';

/// Options for one Bank Link presentation.
///
/// The wrapper adds no flow of its own, so the only thing a host can tune is
/// the [DiditConfig] the native SDK shows the flow with (language, fonts,
/// logging), exactly as it does for [DiditConfig] on a verification.
class BankLinkOptions {
  /// Native configuration: language, fonts, logging. `null` keeps the native
  /// defaults, with the device language resolved by the wrapper.
  final DiditConfig? config;

  const BankLinkOptions({this.config});

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{};
    final config = this.config;
    if (config != null) map['config'] = config.toMap();
    return map;
  }
}

/// Why a Bank Link ended without a connection.
///
/// The values are the wire names of the link contract's `exit.reason`
/// (`events.md` section 3). A reason a newer native SDK adds and this wrapper
/// does not know reads as [failed], never as an exception.
enum BankLinkExitReason {
  /// The person closed the native screen, or the host dismissed it.
  closed,

  /// The person refused the consent, or the link was cancelled.
  cancelled,

  /// The bank cannot be connected right now.
  bankUnavailable,

  /// The link expired before it completed.
  expired,

  /// Any other failure: the flow could not be completed.
  failed;

  /// The `exit.reason` value of the link contract.
  String get wireName => switch (this) {
    BankLinkExitReason.bankUnavailable => 'bank_unavailable',
    BankLinkExitReason.closed => 'closed',
    BankLinkExitReason.cancelled => 'cancelled',
    BankLinkExitReason.expired => 'expired',
    BankLinkExitReason.failed => 'failed',
  };

  static BankLinkExitReason fromWire(String? value) => switch (value) {
    'closed' => BankLinkExitReason.closed,
    'cancelled' => BankLinkExitReason.cancelled,
    'bank_unavailable' => BankLinkExitReason.bankUnavailable,
    'expired' => BankLinkExitReason.expired,
    _ => BankLinkExitReason.failed,
  };
}

/// The one result of a Bank Link: a [BankLinkSuccess] or a [BankLinkExit].
sealed class BankLinkResult {
  const BankLinkResult({required this.resumed});

  /// `true` when the result was replayed after the app was closed during the
  /// bank trip and the host called `DiditSdk.resumeBankLink`, `false`
  /// otherwise.
  final bool resumed;

  /// Maps the result map the platform channel sends.
  ///
  /// Anything else — a missing type, an empty map — is an [BankLinkExit] with
  /// [BankLinkExitReason.failed]: a caller always gets exactly one result and
  /// never an exception from a malformed bridge answer.
  factory BankLinkResult.fromMap(Map<String, dynamic> map) {
    final resumed = map['resumed'] == true;
    if (map['type'] == 'success') {
      final linkId = map['linkId'];
      if (linkId is String && linkId.isNotEmpty) {
        return BankLinkSuccess(
          linkId: linkId,
          connectionId: map['connectionId'] as String?,
          checkId: map['checkId'] as String?,
          resumed: resumed,
        );
      }
    }
    if (map['type'] != 'exit') {
      return BankLinkExit(reason: BankLinkExitReason.failed, resumed: resumed);
    }
    return BankLinkExit(
      reason: BankLinkExitReason.fromWire(map['reason'] as String?),
      step: map['step'] as String?,
      resumed: resumed,
    );
  }
}

/// A link that completed: the ids the host needs, and nothing about the person.
class BankLinkSuccess extends BankLinkResult {
  /// The id of the link (`GET /v3/bank/links/{id}/`).
  final String linkId;

  /// The connection the link created, when the link produced one.
  ///
  /// Never trusted by a server: the webhook and the API are authoritative.
  final String? connectionId;

  /// The check the link created, when the link produced one.
  final String? checkId;

  const BankLinkSuccess({
    required this.linkId,
    this.connectionId,
    this.checkId,
    required super.resumed,
  });
}

/// A link that ended without success.
class BankLinkExit extends BankLinkResult {
  /// Why the link ended.
  final BankLinkExitReason reason;

  /// The native step the person was on when the flow ended, as the server
  /// named it (`consent`, `institution`, `bank_hop`, ...), or `null` before the
  /// first poll.
  final String? step;

  const BankLinkExit({required this.reason, this.step, required super.resumed});
}

/// One event of a running link, with its ids-only payload.
///
/// [name] is the native and web event name (`opened`, `consent_shown`, ...,
/// `success`, `exit`, `error`); [data] holds the snake_case payload keys
/// (`link_id`, `institution_id`, `consent_version`, ...). The wrapper never
/// rewrites either: a name a newer native SDK adds reaches the host as it is.
class BankLinkEvent {
  /// The event name, identical to native and web.
  final String name;

  /// The payload: ids only, never a name, a token or an account number.
  final Map<String, Object?> data;

  const BankLinkEvent({required this.name, this.data = const {}});

  /// Maps one event-channel message.
  factory BankLinkEvent.fromChannel(Object? message) {
    if (message is Map) {
      final name = message['name'];
      final data = message['data'];
      return BankLinkEvent(
        name: name is String ? name : '',
        data: data is Map
            ? <String, Object?>{
                for (final entry in data.entries)
                  entry.key.toString(): entry.value,
              }
            : const <String, Object?>{},
      );
    }
    return const BankLinkEvent(name: '');
  }

  @override
  String toString() => 'BankLinkEvent($name, $data)';
}
