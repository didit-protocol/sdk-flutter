import 'package:flutter/services.dart';

/// Monetary or crypto details of a transaction.
class DiditTransactionInfo {
  /// Transaction direction, e.g. "inbound" or "outbound".
  final String? direction;
  final double? amount;

  /// Currency code, e.g. "USD" or "ETH".
  final String? currency;

  /// Currency type, e.g. "fiat" or "crypto".
  final String? currencyType;
  final double? amountInDefaultCurrency;
  final String? defaultCurrencyCode;
  final String? paymentDetails;
  final String? paymentTxnId;
  final String? type;

  /// Crypto transfer parameters, e.g. {address, chain}.
  final Map<String, dynamic>? cryptoParams;

  const DiditTransactionInfo({
    this.direction,
    this.amount,
    this.currency,
    this.currencyType,
    this.amountInDefaultCurrency,
    this.defaultCurrencyCode,
    this.paymentDetails,
    this.paymentTxnId,
    this.type,
    this.cryptoParams,
  });

  Map<String, dynamic> toMap() => {
        if (direction != null) 'direction': direction,
        if (amount != null) 'amount': amount,
        if (currency != null) 'currency': currency,
        if (currencyType != null) 'currencyType': currencyType,
        if (amountInDefaultCurrency != null)
          'amountInDefaultCurrency': amountInDefaultCurrency,
        if (defaultCurrencyCode != null)
          'defaultCurrencyCode': defaultCurrencyCode,
        if (paymentDetails != null) 'paymentDetails': paymentDetails,
        if (paymentTxnId != null) 'paymentTxnId': paymentTxnId,
        if (type != null) 'type': type,
        if (cryptoParams != null) 'cryptoParams': cryptoParams,
      };
}

/// Payment method of a transaction participant.
class DiditTransactionPaymentMethod {
  final String? type;

  /// Account identifier, e.g. an IBAN, card fingerprint, or wallet address.
  final String? accountId;

  /// ISO 3166-1 alpha-2 issuing country.
  final String? issuingCountry;

  const DiditTransactionPaymentMethod({
    this.type,
    this.accountId,
    this.issuingCountry,
  });

  Map<String, dynamic> toMap() => {
        if (type != null) 'type': type,
        if (accountId != null) 'accountId': accountId,
        if (issuingCountry != null) 'issuingCountry': issuingCountry,
      };
}

/// A transaction participant (subject or counterparty).
class DiditTransactionParticipant {
  /// Participant type, e.g. "individual" or "company".
  final String? type;
  final String? externalUserId;
  final String? fullName;
  final String? firstName;
  final String? lastName;

  /// Date of birth (ISO 8601 date).
  final String? dob;
  final Map<String, dynamic>? address;
  final Map<String, dynamic>? institutionInfo;
  final Map<String, dynamic>? device;
  final DiditTransactionPaymentMethod? paymentMethod;

  const DiditTransactionParticipant({
    this.type,
    this.externalUserId,
    this.fullName,
    this.firstName,
    this.lastName,
    this.dob,
    this.address,
    this.institutionInfo,
    this.device,
    this.paymentMethod,
  });

  Map<String, dynamic> toMap() => {
        if (type != null) 'type': type,
        if (externalUserId != null) 'externalUserId': externalUserId,
        if (fullName != null) 'fullName': fullName,
        if (firstName != null) 'firstName': firstName,
        if (lastName != null) 'lastName': lastName,
        if (dob != null) 'dob': dob,
        if (address != null) 'address': address,
        if (institutionInfo != null) 'institutionInfo': institutionInfo,
        if (device != null) 'device': device,
        if (paymentMethod != null) 'paymentMethod': paymentMethod!.toMap(),
      };
}

/// Travel rule information attached to a transaction.
class DiditTravelRule {
  final String? status;
  final String? protocol;
  final bool? required;
  final int? obligationsCount;
  final Map<String, dynamic>? originatorData;
  final Map<String, dynamic>? beneficiaryData;
  final Map<String, dynamic>? metadata;

  const DiditTravelRule({
    this.status,
    this.protocol,
    this.required,
    this.obligationsCount,
    this.originatorData,
    this.beneficiaryData,
    this.metadata,
  });

  Map<String, dynamic> toMap() => {
        if (status != null) 'status': status,
        if (protocol != null) 'protocol': protocol,
        if (required != null) 'required': required,
        if (obligationsCount != null) 'obligationsCount': obligationsCount,
        if (originatorData != null) 'originatorData': originatorData,
        if (beneficiaryData != null) 'beneficiaryData': beneficiaryData,
        if (metadata != null) 'metadata': metadata,
      };
}

/// A transaction to submit from the device.
///
/// Mirrors the Didit transaction wire contract (camelCase aliases).
class DiditTransactionPayload {
  /// Your unique transaction identifier.
  final String txnId;

  /// Transaction timestamp (ISO 8601).
  final String? txnDate;

  /// Time zone identifier, e.g. "Europe/Madrid".
  final String? zoneId;

  /// Transaction category, e.g. "crypto".
  final String? type;
  final DiditTransactionInfo? info;
  final DiditTransactionParticipant? subject;
  final DiditTransactionParticipant? counterparty;

  /// Custom properties attached to the transaction.
  final Map<String, dynamic>? props;
  final DiditTravelRule? travelRule;
  final bool? includeCryptoScreening;

  const DiditTransactionPayload({
    required this.txnId,
    this.txnDate,
    this.zoneId,
    this.type,
    this.info,
    this.subject,
    this.counterparty,
    this.props,
    this.travelRule,
    this.includeCryptoScreening,
  });

  Map<String, dynamic> toMap() => {
        'txnId': txnId,
        if (txnDate != null) 'txnDate': txnDate,
        if (zoneId != null) 'zoneId': zoneId,
        if (type != null) 'type': type,
        if (info != null) 'info': info!.toMap(),
        if (subject != null) 'subject': subject!.toMap(),
        if (counterparty != null) 'counterparty': counterparty!.toMap(),
        if (props != null) 'props': props,
        if (travelRule != null) 'travelRule': travelRule!.toMap(),
        if (includeCryptoScreening != null)
          'includeCryptoScreening': includeCryptoScreening,
      };
}

/// A user action required to complete the transaction.
class DiditTransactionActionRequired {
  static const String typeVerificationSession = 'verification_session';
  static const String typeWalletOwnership = 'wallet_ownership';

  /// Action type: [typeVerificationSession] or [typeWalletOwnership].
  final String type;

  /// Hosted URL to complete the action.
  final String? url;
  final String? sessionId;
  final String? sessionToken;
  final String? status;
  final String? widgetSessionId;

  /// Expiry timestamp of the wallet-ownership widget session.
  final String? expiresAt;

  const DiditTransactionActionRequired({
    required this.type,
    this.url,
    this.sessionId,
    this.sessionToken,
    this.status,
    this.widgetSessionId,
    this.expiresAt,
  });

  factory DiditTransactionActionRequired.fromMap(Map<String, dynamic> map) {
    return DiditTransactionActionRequired(
      type: map['type'] as String? ?? '',
      url: map['url'] as String?,
      sessionId: map['sessionId'] as String?,
      sessionToken: map['sessionToken'] as String?,
      status: map['status'] as String?,
      widgetSessionId: map['widgetSessionId'] as String?,
      expiresAt: map['expiresAt'] as String?,
    );
  }
}

/// The result of a submitted or fetched transaction.
class DiditTransactionResult {
  final String transactionId;
  final String? status;
  final String? travelRuleStatus;
  final DiditTransactionActionRequired? actionRequired;

  const DiditTransactionResult({
    required this.transactionId,
    this.status,
    this.travelRuleStatus,
    this.actionRequired,
  });

  factory DiditTransactionResult.fromMap(Map<String, dynamic> map) {
    final actionRequired = map['actionRequired'];
    return DiditTransactionResult(
      transactionId: map['transactionId'] as String? ?? '',
      status: map['status'] as String?,
      travelRuleStatus: map['travelRuleStatus'] as String?,
      actionRequired: actionRequired is Map
          ? DiditTransactionActionRequired.fromMap(
              Map<String, dynamic>.from(actionRequired),
            )
          : null,
    );
  }
}

/// Options for submitting or fetching a transaction.
class DiditTransactionOptions {
  /// Override the verification API base URL.
  final String? baseUrl;

  /// Automatically launch any required user action (verification session
  /// or wallet-ownership widget). Default is `true`.
  final bool autoLaunchAction;

  /// Called with the refreshed transaction after an auto-launched action
  /// completes and the transaction status has been re-fetched.
  final void Function(DiditTransactionResult result)? onTransactionUpdated;

  const DiditTransactionOptions({
    this.baseUrl,
    this.autoLaunchAction = true,
    this.onTransactionUpdated,
  });
}

/// Typed exception thrown by the transaction methods.
///
/// Use [code] to discriminate; [fieldErrors] carries per-field details for
/// [codeValidation] failures.
class DiditTransactionException implements Exception {
  static const String codeInvalidToken = 'invalid_token';
  static const String codeExpiredToken = 'expired_token';
  static const String codeValidation = 'validation';
  static const String codeNetwork = 'network';

  /// One of [codeInvalidToken], [codeExpiredToken], [codeValidation],
  /// or [codeNetwork].
  final String code;
  final String message;
  final Map<String, dynamic>? fieldErrors;

  const DiditTransactionException({
    required this.code,
    required this.message,
    this.fieldErrors,
  });

  factory DiditTransactionException.fromPlatformException(
    PlatformException exception,
  ) {
    const codes = {
      codeInvalidToken,
      codeExpiredToken,
      codeValidation,
      codeNetwork,
    };
    final details = exception.details;
    return DiditTransactionException(
      code: codes.contains(exception.code) ? exception.code : codeNetwork,
      message: exception.message ?? 'Transaction request failed.',
      fieldErrors: details is Map ? Map<String, dynamic>.from(details) : null,
    );
  }

  @override
  String toString() => 'DiditTransactionException($code): $message';
}
