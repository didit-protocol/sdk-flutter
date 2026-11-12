import Flutter
import Foundation
#if canImport(DiditAuth)
@preconcurrency import DiditAuth
#else
// A DiditSDK source pod compiles DiditAuth into the DiditSDK module.
@preconcurrency import DiditSDK
#endif

/// Everything that crosses the method channel, and the one place that maps a native failure to the
/// code, message and details Dart turns into a DiditAuthException. The Android plugin
/// (AuthWire.kt) maps the same way, so codes are identical.
enum DiditAuthWire {
    /// The code of a failure that is not a DiditAuth error.
    static let unspecified = "unspecified"

    static func flutterError(_ error: Error) -> FlutterError {
        if let error = error as? DiditAuthError {
            return FlutterError(code: error.code, message: error.message, details: details(error))
        }
        return FlutterError(code: unspecified, message: error.localizedDescription, details: nil)
    }

    /// Status, fields and retry delay, only the ones Didit sent; nil when there are none.
    static func details(_ error: DiditAuthError) -> [String: Any]? {
        var details: [String: Any] = [:]
        if let status = error.status { details["status"] = status }
        if let retryAfter = error.retryAfter { details["retryAfter"] = retryAfter }
        if let fields = error.fields { details["fields"] = fields }
        return details.isEmpty ? nil : details
    }

    static func stepUpAction(_ action: String?, amount: String?, currency: String?) throws -> DiditStepUpAction {
        switch action {
        case "payout":
            guard let amount = amount else {
                throw DiditAuthError("invalid_request", "A payout step-up needs an amount.")
            }
            return .payout(amount: amount, currency: currency)
        case "bank":
            return .bankAccount
        case "contact":
            return .contactChange
        default:
            throw DiditAuthError("invalid_request", "Unknown step-up action: \(action ?? "none").")
        }
    }

    static func sessionJson(_ session: DiditSession) throws -> String {
        try json([
            "userId": session.userId,
            "sessionId": session.sessionId,
            "applicationId": session.applicationId,
            "vendorData": orNull(session.vendorData),
            "email": orNull(session.email),
            "emailVerified": session.emailVerified,
            "phone": orNull(session.phone),
            "methods": session.methods,
            "mfaVerified": session.mfaVerified,
            "verified": orNull(session.verified),
            "organizations": session.organizations.map { ["id": $0.id, "name": $0.name, "role": $0.role] },
            "expiresAt": session.expiresAt,
        ])
    }

    static func stepUpResultJson(_ result: DiditStepUpResult) throws -> String {
        try json([
            "id": orNull(result.id),
            "status": result.status,
            "approved": result.isApproved,
            "rule": orNull(result.rule),
            "method": orNull(result.method),
        ])
    }

    private static func orNull(_ value: Any?) -> Any {
        value ?? NSNull()
    }

    private static func json(_ object: [String: Any]) throws -> String {
        guard JSONSerialization.isValidJSONObject(object) else {
            throw DiditAuthError("server_error", "The answer cannot be sent to Dart.")
        }
        return String(decoding: try JSONSerialization.data(withJSONObject: object), as: UTF8.self)
    }
}
