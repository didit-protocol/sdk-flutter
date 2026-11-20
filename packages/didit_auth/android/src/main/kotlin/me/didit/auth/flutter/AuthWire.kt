package me.didit.auth.flutter

import me.didit.sdk.auth.DiditAuthException
import me.didit.sdk.auth.DiditReauthMethod
import me.didit.sdk.auth.DiditSession
import me.didit.sdk.auth.DiditStepUpAction
import me.didit.sdk.auth.DiditStepUpResult
import org.json.JSONArray
import org.json.JSONObject

/**
 * Everything that crosses the method channel, and the one place that maps a native
 * failure to the code, message and details Dart turns into a DiditAuthException.
 * The iOS plugin (DiditAuthWire.swift) maps the same way, so codes are identical.
 */
internal object AuthWire {
    /** The code of a failure that is not a DiditAuth error. */
    const val UNSPECIFIED = "unspecified"

    /** What `Result.error` takes. */
    class ErrorReply(val code: String, val message: String?, val details: Map<String, Any>?)

    fun errorReply(error: Throwable): ErrorReply = when (error) {
        is DiditAuthException -> ErrorReply(error.code, error.message, details(error))
        else -> ErrorReply(UNSPECIFIED, error.message, null)
    }

    /** Status, fields and retry delay, only the ones Didit sent; null when there are none. */
    private fun details(error: DiditAuthException): Map<String, Any>? {
        val details = mutableMapOf<String, Any>()
        error.status?.let { details["status"] = it }
        error.retryAfterSeconds?.let { details["retryAfter"] = it }
        error.fields?.let { details["fields"] = it }
        return details.ifEmpty { null }
    }

    /** Android validates the redirect with require(); iOS throws this code for it. */
    fun invalidRedirectUri(error: IllegalArgumentException) = DiditAuthException(
        "invalid_redirect_uri",
        error.message ?: "redirectUri is not a valid HTTPS address."
    )

    fun stepUpAction(action: String?, amount: String?, currency: String?): DiditStepUpAction = when (action) {
        "payout" -> DiditStepUpAction.Payout(
            amount ?: throw DiditAuthException("invalid_request", "A payout step-up needs an amount."),
            currency
        )
        "bank" -> DiditStepUpAction.BankAccount
        "contact" -> DiditStepUpAction.ContactChange
        else -> throw DiditAuthException("invalid_request", "Unknown step-up action: $action.")
    }

    /** The method of a re-authentication; no value is the native default, the hosted page. */
    fun reauthMethod(method: String?): DiditReauthMethod = when (method) {
        null, "hosted" -> DiditReauthMethod.HOSTED
        "passkey" -> DiditReauthMethod.PASSKEY
        else -> throw DiditAuthException("invalid_request", "Unknown re-authentication method: $method.")
    }

    fun sessionJson(session: DiditSession): String = toJson(
        mapOf(
            "userId" to session.userId,
            "sessionId" to session.sessionId,
            "applicationId" to session.applicationId,
            "vendorData" to session.vendorData,
            "email" to session.email,
            "emailVerified" to session.emailVerified,
            "phone" to session.phone,
            "methods" to session.methods,
            "mfaVerified" to session.mfaVerified,
            "verified" to session.verified,
            "organizations" to session.organizations.map {
                mapOf("id" to it.id, "name" to it.name, "role" to it.role)
            },
            "expiresAt" to session.expiresAt
        )
    ).toString()

    fun stepUpResultJson(result: DiditStepUpResult): String = toJson(
        mapOf(
            "id" to result.id,
            "status" to result.status,
            "approved" to result.isApproved,
            "rule" to result.rule,
            "method" to result.method
        )
    ).toString()

    /** JSON keeping nulls (org.json drops null map values). */
    private fun toJson(value: Any?): Any = when (value) {
        null -> JSONObject.NULL
        is Map<*, *> -> JSONObject().apply { value.forEach { (key, item) -> put(key.toString(), toJson(item)) } }
        is Iterable<*> -> JSONArray().apply { value.forEach { put(toJson(it)) } }
        else -> value
    }
}
