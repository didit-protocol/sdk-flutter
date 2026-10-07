package me.didit.sdk.sdk_flutter

import android.app.Activity
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.mockk.Runs
import io.mockk.every
import io.mockk.just
import io.mockk.mockk
import io.mockk.mockkObject
import io.mockk.slot
import io.mockk.unmockkObject
import io.mockk.verify
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.setMain
import me.didit.sdk.Configuration
import me.didit.sdk.DiditSdk
import me.didit.sdk.DiditSdkState
import me.didit.sdk.SessionData
import me.didit.sdk.VerificationError
import me.didit.sdk.VerificationResult
import me.didit.sdk.VerificationStatus
import me.didit.sdk.core.localization.SupportedLanguage
import kotlin.test.AfterTest
import kotlin.test.BeforeTest
import kotlin.test.Test
import kotlin.test.assertEquals

/*
 * The native SDK runs every step of the flow, Bank and Location included, inside its own
 * activity, and reports a single VerificationResult when the flow ends. These tests drive
 * the plugin through the method channel against a stubbed DiditSdk: the call reaches the
 * native SDK with the Dart configuration, the native UI opens once the session is ready,
 * and every result shape reaches Dart as the map VerificationResult.fromMap reads.
 *
 * Run them with `./gradlew :didit_sdk:testDebugUnitTest` from example/android.
 */
@OptIn(ExperimentalCoroutinesApi::class)
internal class SdkFlutterPluginTest {
    private val hostActivity = mockk<Activity>()
    private val result = mockk<MethodChannel.Result>(relaxed = true)
    private val sdkState = MutableStateFlow<DiditSdkState>(DiditSdkState.Idle)
    private val configuration = slot<Configuration>()
    private val onResult = slot<(VerificationResult) -> Unit>()
    private val delivered = mutableListOf<Any?>()
    private lateinit var plugin: SdkFlutterPlugin

    @BeforeTest
    fun setUp() {
        Dispatchers.setMain(UnconfinedTestDispatcher())
        mockkObject(DiditSdk)
        every { DiditSdk.state } returns sdkState
        every { DiditSdk.launchVerificationUI(any()) } just Runs
        every {
            DiditSdk.startVerification(
                token = any(),
                configuration = capture(configuration),
                onResult = capture(onResult)
            )
        } answers { sdkState.value = DiditSdkState.Ready }
        every {
            DiditSdk.startVerification(
                workflowId = any(),
                vendorData = any(),
                configuration = capture(configuration),
                onResult = capture(onResult)
            )
        } answers { sdkState.value = DiditSdkState.Ready }
        every { result.success(any()) } answers { delivered += firstArg<Any?>() }

        plugin = SdkFlutterPlugin()
        plugin.onAttachedToActivity(mockk<ActivityPluginBinding> {
            every { activity } returns hostActivity
        })
    }

    @AfterTest
    fun tearDown() {
        unmockkObject(DiditSdk)
        Dispatchers.resetMain()
    }

    private fun startVerification(config: Map<String, Any> = mapOf("languageCode" to "es")) {
        plugin.onMethodCall(
            MethodCall("startVerification", mapOf("token" to "session-token", "config" to config)),
            result
        )
    }

    // Starts a verification, lets the native SDK finish it with [nativeResult] and
    // returns what the plugin sent back to Dart.
    private fun deliver(nativeResult: VerificationResult): Any? {
        startVerification()
        onResult.captured(nativeResult)
        return delivered.last()
    }

    @Test
    fun startVerification_passesTokenAndConfigToNative_thenOpensItsUi() {
        startVerification(mapOf("languageCode" to "es", "showCloseButton" to false))

        verify { DiditSdk.startVerification(token = "session-token", configuration = any(), onResult = any()) }
        assertEquals(SupportedLanguage.SPANISH, configuration.captured.languageLocale)
        assertEquals(false, configuration.captured.showCloseButton)
        verify(exactly = 1) { DiditSdk.launchVerificationUI(hostActivity) }
        assertEquals(emptyList(), delivered)
    }

    @Test
    fun startVerificationWithWorkflow_passesWorkflowAndVendorDataToNative_thenOpensItsUi() {
        plugin.onMethodCall(
            MethodCall(
                "startVerificationWithWorkflow",
                mapOf(
                    "workflowId" to "workflow-id",
                    "vendorData" to "user-1",
                    "config" to mapOf("languageCode" to "es")
                )
            ),
            result
        )

        verify {
            DiditSdk.startVerification(
                workflowId = "workflow-id",
                vendorData = "user-1",
                configuration = any(),
                onResult = any()
            )
        }
        assertEquals(SupportedLanguage.SPANISH, configuration.captured.languageLocale)
        verify(exactly = 1) { DiditSdk.launchVerificationUI(hostActivity) }
    }

    @Test
    fun completedSession_returnsItsIdAndFinalStatus() {
        for (status in VerificationStatus.entries) {
            assertEquals(
                mapOf("type" to "completed", "sessionId" to "session-1", "status" to status.rawValue),
                deliver(VerificationResult.Completed(SessionData("session-1", status)))
            )
        }
    }

    @Test
    fun cancelledSession_returnsTheSessionWhenOneExists() {
        assertEquals(
            mapOf("type" to "cancelled", "sessionId" to "session-1", "status" to "Pending"),
            deliver(VerificationResult.Cancelled(SessionData("session-1", VerificationStatus.PENDING)))
        )
        assertEquals(mapOf("type" to "cancelled"), deliver(VerificationResult.Cancelled(null)))
    }

    @Test
    fun failedSession_returnsTheErrorTypeAndMessage() {
        val errorTypes = mapOf(
            VerificationError.SessionExpired to "sessionExpired",
            VerificationError.NetworkError to "networkError",
            VerificationError.CameraAccessDenied to "cameraAccessDenied",
            VerificationError.NotInitialized to "notInitialized",
            VerificationError.RetryBlocked to "retryBlocked",
            VerificationError.ApiError(503, "Service unavailable") to "apiError",
            VerificationError.Unknown("Unsupported verification step") to "unknown"
        )
        for ((error, errorType) in errorTypes) {
            assertEquals(
                mapOf(
                    "type" to "failed",
                    "errorType" to errorType,
                    "errorMessage" to error.message,
                    "sessionId" to "session-1",
                    "status" to "Pending"
                ),
                deliver(
                    VerificationResult.Failed(error, SessionData("session-1", VerificationStatus.PENDING))
                )
            )
        }
    }

    @Test
    fun nativeStartError_returnsTheNativeFailureWithoutOpeningTheUi() {
        every {
            DiditSdk.startVerification(token = any(), configuration = any(), onResult = any())
        } answers {
            sdkState.value = DiditSdkState.Error("Session not found")
            arg<(VerificationResult) -> Unit>(2)(
                VerificationResult.Failed(VerificationError.Unknown("Session not found"), null)
            )
        }

        startVerification()

        verify(exactly = 0) { DiditSdk.launchVerificationUI(any()) }
        assertEquals(
            listOf(mapOf("type" to "failed", "errorType" to "unknown", "errorMessage" to "Session not found")),
            delivered
        )
    }

    @Test
    fun startVerification_withoutAnActivity_failsWithoutOpeningTheUi() {
        plugin.onDetachedFromActivity()

        startVerification()

        verify(exactly = 0) { DiditSdk.launchVerificationUI(any()) }
        assertEquals(
            listOf(
                mapOf(
                    "type" to "failed",
                    "errorType" to "unknown",
                    "errorMessage" to "No active Activity available to present verification UI."
                )
            ),
            delivered
        )
    }

    @Test
    fun startVerification_withoutAToken_isRejectedBeforeReachingNative() {
        plugin.onMethodCall(MethodCall("startVerification", mapOf<String, Any>()), result)

        verify { result.error("INVALID_ARGUMENT", "Token is required", null) }
        verify(exactly = 0) { DiditSdk.startVerification(token = any(), configuration = any(), onResult = any()) }
    }

    @Test
    fun unknownMethod_isNotImplemented() {
        plugin.onMethodCall(MethodCall("getPlatformVersion", null), result)

        verify { result.notImplemented() }
    }
}
