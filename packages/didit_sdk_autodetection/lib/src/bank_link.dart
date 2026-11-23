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
  ///
  /// This is also how a link that has already finished ends when it is
  /// opened again: the service answers `410 link_ended` with its
  /// `link_status` (`completed` or `failed`), the native SDK shows the ending
  /// that status names, and the result is a `failed` exit either way. A link
  /// open in another instance (`409 link_already_redeemed`) ends the same way;
  /// that code no longer means a finished link.
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
          connectionId: _stringOf(map['connectionId']),
          checkId: _stringOf(map['checkId']),
          resumed: resumed,
        );
      }
    }
    if (map['type'] != 'exit') {
      return BankLinkExit(reason: BankLinkExitReason.failed, resumed: resumed);
    }
    return BankLinkExit(
      reason: BankLinkExitReason.fromWire(_stringOf(map['reason'])),
      step: _stringOf(map['step']),
      resumed: resumed,
    );
  }

  /// A field the bridge sent as something other than a string is read as
  /// absent: a malformed answer still settles the future, never throws.
  static String? _stringOf(Object? value) {
    if (value is String && value.isNotEmpty) return value;
    return null;
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
/// renames either: a name a newer native SDK adds reaches the host as it is,
/// with its `link_id` only. Keys outside an event's contract are dropped.
///
/// Once the person picks a bank, the native session state names it
/// (`detail.institution_id`, `detail.institution_name`) and the native screens
/// show that name; events still carry only `institution_id`, never the name.
class BankLinkEvent {
  /// The event name, identical to native and web.
  final String name;

  /// The payload: ids only, never a name, a token or an account number.
  final Map<String, Object?> data;

  const BankLinkEvent({required this.name, this.data = const {}});

  /// The payload keys each known event may carry (ids and short codes only).
  /// A key outside the list is dropped, so a token or a session credential can
  /// never reach a host through the stream, whatever native sends.
  static const Map<String, Set<String>> _allowedKeys = {
    'opened': {'link_id', 'mode', 'access', 'presentation'},
    'consent_shown': {'link_id', 'consent_version'},
    'consent_accepted': {'link_id', 'consent_version'},
    'institution_selected': {'link_id', 'institution_id', 'country'},
    'bank_redirect': {'link_id', 'via'},
    'bank_returned': {'link_id', 'result'},
    'accounts_selected': {'link_id', 'count'},
    'success': {'link_id', 'connection_id', 'check_id'},
    'exit': {'link_id', 'reason', 'step'},
    'error': {'link_id', 'code'},
  };

  /// Maps one event-channel message, or returns `null` for a malformed one
  /// (not a map, or without a non-empty string `name`), which the stream drops.
  ///
  /// A name a newer native SDK adds is kept, with only its `link_id`.
  static BankLinkEvent? fromChannel(Object? message) {
    if (message is! Map) return null;
    final name = message['name'];
    if (name is! String || name.isEmpty) return null;
    final data = message['data'];
    final allowed = _allowedKeys[name] ?? const {'link_id'};
    return BankLinkEvent(
      name: name,
      data: data is Map
          ? <String, Object?>{
              for (final entry in data.entries)
                if (allowed.contains(entry.key.toString()))
                  entry.key.toString(): entry.value,
            }
          : const <String, Object?>{},
    );
  }

  @override
  String toString() => 'BankLinkEvent($name, $data)';
}
