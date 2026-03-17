package me.didit.sdk.sdk_flutter

import android.app.Activity
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import me.didit.sdk.Configuration
import me.didit.sdk.DiditSdk
import me.didit.sdk.DiditSdkState
import me.didit.sdk.SessionData
import me.didit.sdk.VerificationError
import me.didit.sdk.VerificationResult
import me.didit.sdk.VerificationStatus
import me.didit.sdk.core.localization.SupportedLanguage

class SdkFlutterPlugin :
    FlutterPlugin,
    MethodCallHandler,
    ActivityAware {

    private lateinit var channel: MethodChannel
    private var activity: Activity? = null
    private var applicationContext: android.content.Context? = null
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    // ── FlutterPlugin ────────────────────────────────────────────────────────

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "didit_sdk")
        channel.setMethodCallHandler(this)
        applicationContext = binding.applicationContext

        if (!DiditSdk.isInitialized()) {
            DiditSdk.initialize(binding.applicationContext)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        applicationContext = null
    }

    // ── ActivityAware ────────────────────────────────────────────────────────

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    // ── MethodCallHandler ────────────────────────────────────────────────────

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "startVerification" -> handleStartVerification(call, result)
            "startVerificationWithWorkflow" -> handleStartVerificationWithWorkflow(call, result)
            else -> result.notImplemented()
        }
    }

    // ── Start Verification with Token ────────────────────────────────────────

    private fun handleStartVerification(call: MethodCall, result: Result) {
        val token = call.argument<String>("token")
        if (token == null) {
            result.error("INVALID_ARGUMENT", "Token is required", null)
            return
        }

        val config = parseConfiguration(call.argument<Map<String, Any>>("config"))

        scope.launch {
            try {
                DiditSdk.startVerification(
                    token = token,
                    configuration = config
                ) { verificationResult ->
                    result.success(mapVerificationResult(verificationResult))
                }

                awaitReadyAndLaunchUI(result)
            } catch (e: Exception) {
                resolveWithError(result, e)
            }
        }
    }

    // ── Start Verification with Workflow ──────────────────────────────────────

    private fun handleStartVerificationWithWorkflow(call: MethodCall, result: Result) {
        val workflowId = call.argument<String>("workflowId")
        if (workflowId == null) {
            result.error("INVALID_ARGUMENT", "Workflow ID is required", null)
            return
        }

        val config = parseConfiguration(call.argument<Map<String, Any>>("config"))

        scope.launch {
            try {
                DiditSdk.startVerification(
                    workflowId = workflowId,
                    vendorData = call.argument<String>("vendorData"),
                    configuration = config
                ) { verificationResult ->
                    result.success(mapVerificationResult(verificationResult))
                }

                awaitReadyAndLaunchUI(result)
            } catch (e: Exception) {
                resolveWithError(result, e)
            }
        }
    }

    // ── State Observation & UI Launching ──────────────────────────────────────

    private suspend fun awaitReadyAndLaunchUI(result: Result) {
        DiditSdk.state.first { state ->
            when (state) {
                is DiditSdkState.Ready -> {
                    val currentActivity = activity
                    if (currentActivity != null) {
                        DiditSdk.launchVerificationUI(currentActivity)
                    } else {
                        val errorResult = mapOf(
                            "type" to "failed",
                            "errorType" to "unknown",
                            "errorMessage" to "No active Activity available to present verification UI."
                        )
                        result.success(errorResult)
                    }
                    true
                }
                is DiditSdkState.Error -> true
                else -> false
            }
        }
    }

    // ── Configuration Parsing ────────────────────────────────────────────────

    private fun parseConfiguration(map: Map<String, Any>?): Configuration? {
        if (map == null) return null

        var language: SupportedLanguage? = null
        val code = map["languageCode"] as? String
        if (code != null) {
            language = SupportedLanguage.fromCode(code)
        }

        return Configuration(
            languageLocale = language,
            fontFamily = map["fontFamily"] as? String,
            loggingEnabled = map["loggingEnabled"] as? Boolean ?: false
        )
    }

    // ── Result Mapping ───────────────────────────────────────────────────────

    private fun mapVerificationResult(result: VerificationResult): Map<String, Any?> {
        val map = mutableMapOf<String, Any?>()

        when (result) {
            is VerificationResult.Completed -> {
                map["type"] = "completed"
                putSessionData(map, result.session)
            }
            is VerificationResult.Cancelled -> {
                map["type"] = "cancelled"
                result.session?.let { putSessionData(map, it) }
            }
            is VerificationResult.Failed -> {
                map["type"] = "failed"
                map["errorType"] = mapErrorType(result.error)
                map["errorMessage"] = result.error.message ?: "An unknown error occurred."
                result.session?.let { putSessionData(map, it) }
            }
        }

        return map
    }

    private fun putSessionData(map: MutableMap<String, Any?>, session: SessionData) {
        map["sessionId"] = session.sessionId
        map["status"] = session.status.rawValue
    }

    private fun mapErrorType(error: VerificationError): String {
        return when (error) {
            is VerificationError.SessionExpired -> "sessionExpired"
            is VerificationError.NetworkError -> "networkError"
            is VerificationError.CameraAccessDenied -> "cameraAccessDenied"
            is VerificationError.NotInitialized -> "notInitialized"
            is VerificationError.ApiError -> "apiError"
            is VerificationError.Unknown -> "unknown"
        }
    }

    private fun resolveWithError(result: Result, e: Exception) {
        val errorResult = mapOf(
            "type" to "failed",
            "errorType" to "unknown",
            "errorMessage" to (e.message ?: "An unexpected error occurred.")
        )
        result.success(errorResult)
    }
}
