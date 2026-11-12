package me.didit.auth.flutter

import me.didit.sdk.auth.DiditAuthException
import me.didit.sdk.auth.DiditOrganization
import me.didit.sdk.auth.DiditReauthMethod
import me.didit.sdk.auth.DiditSession
import me.didit.sdk.auth.DiditStepUpAction
import me.didit.sdk.auth.DiditStepUpResult
import org.json.JSONObject
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertNull
import kotlin.test.assertTrue

class AuthWireTest {
    @Test
    fun `a DiditAuth error keeps its code and message and carries status, fields and retry delay`() {
        val reply = AuthWire.errorReply(
            DiditAuthException(
                "rate_limited",
                "Slow down.",
                status = 429,
                fields = mapOf("return_to" to listOf("invalid_redirect_uri")),
                retryAfterSeconds = 12
            )
        )

        assertEquals("rate_limited", reply.code)
        assertEquals("Slow down.", reply.message)
        assertEquals(
            mapOf("status" to 429, "retryAfter" to 12, "fields" to mapOf("return_to" to listOf("invalid_redirect_uri"))),
            reply.details
        )
    }

    @Test
    fun `an error with nothing extra has no details`() {
        val reply = AuthWire.errorReply(DiditAuthException("cancelled"))

        assertEquals("cancelled", reply.code)
        assertEquals("cancelled", reply.message)
        assertNull(reply.details)
    }

    @Test
    fun `a failure that is not a DiditAuth error is unspecified`() {
        val reply = AuthWire.errorReply(IllegalStateException("boom"))

        assertEquals("unspecified", reply.code)
        assertEquals("boom", reply.message)
        assertNull(reply.details)
    }

    @Test
    fun `an invalid redirect maps to the code iOS uses`() {
        val error = AuthWire.invalidRedirectUri(IllegalArgumentException("not https"))

        assertEquals("invalid_redirect_uri", error.code)
        assertEquals("not https", error.message)
    }

    @Test
    fun `step-up actions map to the native ones`() {
        assertEquals(DiditStepUpAction.Payout("900.00", "EUR"), AuthWire.stepUpAction("payout", "900.00", "EUR"))
        assertEquals(DiditStepUpAction.Payout("5.00", null), AuthWire.stepUpAction("payout", "5.00", null))
        assertEquals(DiditStepUpAction.BankAccount, AuthWire.stepUpAction("bank", null, null))
        assertEquals(DiditStepUpAction.ContactChange, AuthWire.stepUpAction("contact", null, null))
    }

    @Test
    fun `a payout without an amount and an unknown action are invalid requests`() {
        assertEquals("invalid_request", assertFailsWith<DiditAuthException> { AuthWire.stepUpAction("payout", null, null) }.code)
        assertEquals("invalid_request", assertFailsWith<DiditAuthException> { AuthWire.stepUpAction("refund", null, null) }.code)
        assertEquals("invalid_request", assertFailsWith<DiditAuthException> { AuthWire.stepUpAction(null, null, null) }.code)
    }

    @Test
    fun `re-authentication methods map to the native ones, hosted by default`() {
        assertEquals(DiditReauthMethod.HOSTED, AuthWire.reauthMethod("hosted"))
        assertEquals(DiditReauthMethod.PASSKEY, AuthWire.reauthMethod("passkey"))
        assertEquals(DiditReauthMethod.HOSTED, AuthWire.reauthMethod(null))
    }

    @Test
    fun `an unknown re-authentication method is an invalid request`() {
        assertEquals("invalid_request", assertFailsWith<DiditAuthException> { AuthWire.reauthMethod("password") }.code)
    }

    @Test
    fun `a user mismatch keeps its code on the wire`() {
        val reply = AuthWire.errorReply(DiditAuthException("step_up_user_mismatch", "A different person completed the sign-in."))

        assertEquals("step_up_user_mismatch", reply.code)
        assertNull(reply.details)
    }

    @Test
    fun `a session keeps its nulls and nested values`() {
        val json = JSONObject(
            AuthWire.sessionJson(
                DiditSession(
                    userId = "user-1",
                    sessionId = "session-1",
                    applicationId = "app-1",
                    vendorData = null,
                    email = "person@example.com",
                    emailVerified = true,
                    phone = null,
                    methods = listOf("passkey"),
                    mfaVerified = false,
                    verified = mapOf("level" to "full", "claims" to mapOf("age_over_18" to true)),
                    organizations = listOf(DiditOrganization("org-1", "Example", "admin")),
                    expiresAt = "2030-01-02T03:04:05Z"
                )
            )
        )

        assertEquals("user-1", json.getString("userId"))
        assertTrue(json.isNull("vendorData"))
        assertTrue(json.has("vendorData"))
        assertTrue(json.isNull("phone"))
        assertEquals("passkey", json.getJSONArray("methods").getString(0))
        assertTrue(json.getJSONObject("verified").getJSONObject("claims").getBoolean("age_over_18"))
        assertEquals("admin", json.getJSONArray("organizations").getJSONObject(0).getString("role"))
        assertEquals("2030-01-02T03:04:05Z", json.getString("expiresAt"))
    }

    @Test
    fun `a session without a verified level has a null one`() {
        val json = JSONObject(
            AuthWire.sessionJson(
                DiditSession("u", "s", "a", null, null, false, null, emptyList(), false, null, emptyList(), "2030-01-02T03:04:05Z")
            )
        )

        assertTrue(json.has("verified"))
        assertTrue(json.isNull("verified"))
    }

    @Test
    fun `a step-up result says whether the action may go ahead`() {
        val approved = JSONObject(AuthWire.stepUpResultJson(DiditStepUpResult("id-1", "approved", "payout", "liveness")))
        val notRequired = JSONObject(AuthWire.stepUpResultJson(DiditStepUpResult(null, "not_required")))
        val declined = JSONObject(AuthWire.stepUpResultJson(DiditStepUpResult("id-2", "declined", "device", "selfie")))

        assertTrue(approved.getBoolean("approved"))
        assertEquals("liveness", approved.getString("method"))
        assertTrue(notRequired.getBoolean("approved"))
        assertTrue(notRequired.isNull("id"))
        assertTrue(notRequired.has("rule"))
        assertEquals(false, declined.getBoolean("approved"))
    }
}
