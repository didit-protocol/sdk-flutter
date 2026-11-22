package me.didit.sdk.sdk_flutter

import android.app.Activity
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import me.didit.sdk.CameraLens
import me.didit.sdk.Configuration
import me.didit.sdk.DiditSdk
import me.didit.sdk.DiditSdkState
import me.didit.sdk.SessionData
import me.didit.sdk.VerificationError
import me.didit.sdk.VerificationResult
import me.didit.sdk.VerificationStatus
import me.didit.sdk.core.localization.SupportedLanguage
import me.didit.sdk.transactions.DiditTransactionException
import me.didit.sdk.transactions.DiditTransactionInfo
import me.didit.sdk.transactions.DiditTransactionOptions
import me.didit.sdk.transactions.DiditTransactionParticipant
import me.didit.sdk.transactions.DiditTransactionPayload
import me.didit.sdk.transactions.DiditTransactionPaymentMethod
import me.didit.sdk.transactions.DiditTransactionResult
import me.didit.sdk.transactions.DiditTravelRule

class SdkFlutterPlugin :
    FlutterPlugin,
    MethodCallHandler,
    ActivityAware {

    private lateinit var channel: MethodChannel
    private var bankLinkEvents: EventChannel.EventSink? = null
    private var activity: Activity? = null

    /**
     * The Bank Link hand-off. The build picks the released-AAR bridge or the one
     * that calls a native version carrying Bank Link; tests replace it with a
     * fake native module.
     */
    internal var bankLinkBridge: BankLinkBridge = newBankLinkBridge()

    /** The link on screen, so a result reaches Dart exactly once. */
    private var openBankLink: BankLinkCall? = null
    private var applicationContext: android.content.Context? = null
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    // ── FlutterPlugin ────────────────────────────────────────────────────────

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "didit_sdk")
        channel.setMethodCallHandler(this)
        EventChannel(binding.binaryMessenger, "didit_sdk/bank_link_events")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    bankLinkEvents = events
                }

                override fun onCancel(arguments: Any?) {
                    bankLinkEvents = null
                }
            })
        applicationContext = binding.applicationContext

        if (!DiditSdk.isInitialized()) {
            DiditSdk.initialize(binding.applicationContext)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        bankLinkEvents = null
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
            "submitTransaction" -> handleSubmitTransaction(call, result)
            "getTransaction" -> handleGetTransaction(call, result)
            "presentBankLink" -> handlePresentBankLink(call, result)
            "resumeBankLink" -> handleResumeBankLink(result)
            "handleBankLinkReturn" -> handleBankLinkReturn(call, result)
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

        val defaultDocumentCamera = parseCameraLens(map["defaultDocumentCamera"] as? String)
            ?: CameraLens.BACK
        val defaultLivenessCamera = parseCameraLens(map["defaultLivenessCamera"] as? String)
            ?: CameraLens.FRONT

        return Configuration(
            languageLocale = language,
            showLanguageSelector = map["showLanguageSelector"] as? Boolean ?: false,
            fontFamily = map["fontFamily"] as? String,
            loggingEnabled = map["loggingEnabled"] as? Boolean ?: false,
            showCloseButton = map["showCloseButton"] as? Boolean ?: true,
            showExitConfirmation = map["showExitConfirmation"] as? Boolean ?: true,
            closeOnComplete = map["closeOnComplete"] as? Boolean ?: false,
            defaultDocumentCamera = defaultDocumentCamera,
            defaultLivenessCamera = defaultLivenessCamera,
            showDocumentCameraSwitchButton = map["showDocumentCameraSwitchButton"] as? Boolean ?: true,
            showLivenessCameraSwitchButton = map["showLivenessCameraSwitchButton"] as? Boolean ?: true
        )
    }

    private fun parseCameraLens(value: String?): CameraLens? = when (value?.lowercase()) {
        "front" -> CameraLens.FRONT
        "back" -> CameraLens.BACK
        else -> null
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
            is VerificationError.RetryBlocked -> "retryBlocked"
            is VerificationError.Unknown -> "unknown"
            else -> "unknown"
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

    // ── Bank Link ────────────────────────────────────────────────────────────
    //
    // The wrapper adds no flow of its own: the native SDK owns every screen of
    // Bank Link, its copy and its state machine. The plugin owns the seam: it
    // hands the token and the configuration over, forwards every event to the
    // `didit_sdk/bank_link_events` channel, and settles the Dart future with the
    // one result the native flow delivers.

    /** One `presentBankLink`/`resumeBankLink` call, and its one answer to Dart. */
    private class BankLinkCall(val result: Result) {
        var delivered = false
    }

    private fun handlePresentBankLink(call: MethodCall, result: Result) {
        val token = call.argument<String>("token")
        if (token.isNullOrEmpty()) {
            result.error("INVALID_ARGUMENT", "Token is required", null)
            return
        }
        val host = activity
        if (host == null) {
            result.error(
                "unavailable",
                "No active Activity to present a Bank Link from.",
                null
            )
            return
        }
        // One link at a time, like a verification: a second call settles as a
        // failed exit instead of opening a second flow.
        if (openBankLink != null) {
            result.success(
                BankLinkWire.Outcome.Exit(
                    reason = "failed",
                    step = null,
                    resumed = false
                ).toMap()
            )
            return
        }

        val options = call.argument<Map<String, Any?>>("options")
        val configuration = parseConfiguration(
            options?.get("config") as? Map<String, Any>
        )

        val link = BankLinkCall(result)
        openBankLink = link
        val started = bankLinkBridge.present(
            host,
            token,
            configuration,
            onEvent = ::emitBankLinkEvent
        ) { outcome -> resolveBankLink(link, outcome) }

        if (!started) {
            if (openBankLink === link) openBankLink = null
            if (!link.delivered) {
                result.error(
                    "unavailable",
                    "This version of the native Didit SDK does not carry Bank Link.",
                    null
                )
            }
        }
    }

    private fun handleResumeBankLink(result: Result) {
        val host = activity
        if (host == null) {
            // Nothing to resume: a native layer without a screen kept no link,
            // and Dart reads null as "nothing pending".
            result.success(null)
            return
        }

        val link = BankLinkCall(result)
        val previous = openBankLink
        openBankLink = link
        val resumed = bankLinkBridge.resume(
            host,
            onEvent = ::emitBankLinkEvent
        ) { outcome -> resolveBankLink(link, outcome) }

        if (!resumed) {
            if (openBankLink === link) openBankLink = previous
            if (!link.delivered) result.success(null)
        }
    }

    private fun handleBankLinkReturn(call: MethodCall, result: Result) {
        val url = call.argument<String>("url")
        if (url.isNullOrEmpty()) {
            result.error("INVALID_ARGUMENT", "url is required", null)
            return
        }
        // The address reaches the native handler unchanged: a resume code
        // carries a dot and arrives in a query parameter, so nothing here
        // splits or validates it.
        result.success(bankLinkBridge.handleReturn(url))
    }

    /** Every event of the running link, ids only, in the contract's shape. */
    private fun emitBankLinkEvent(event: BankLinkWire.Event) {
        bankLinkEvents?.success(event.toMap())
    }

    /** The one result of one call: a late or repeated answer is dropped. */
    private fun resolveBankLink(link: BankLinkCall, outcome: BankLinkWire.Outcome) {
        if (link.delivered) return
        link.delivered = true
        if (openBankLink === link) openBankLink = null
        link.result.success(outcome.toMap())
    }

    // ── Transactions ─────────────────────────────────────────────────────────

    private fun handleSubmitTransaction(call: MethodCall, result: Result) {
        val transactionToken = call.argument<String>("transactionToken")
        val transaction = call.argument<Map<String, Any?>>("transaction")
        val txnId = transaction?.get("txnId") as? String
        if (transactionToken == null || transaction == null || txnId == null) {
            result.error("validation", "transactionToken and transaction.txnId are required", null)
            return
        }
        val options = call.argument<Map<String, Any?>>("options") ?: emptyMap()
        val callId = options["callId"] as? String ?: ""
        scope.launch {
            try {
                val transactionResult = DiditSdk.submitTransaction(
                    transactionToken = transactionToken,
                    transaction = parseTransactionPayload(txnId, transaction),
                    options = DiditTransactionOptions(
                        baseUrl = options["baseUrl"] as? String,
                        autoLaunchAction = options["autoLaunchAction"] as? Boolean ?: true,
                        onTransactionUpdated = { refreshed ->
                            channel.invokeMethod(
                                "onTransactionUpdated",
                                mapOf(
                                    "callId" to callId,
                                    "result" to mapTransactionResult(refreshed)
                                )
                            )
                        }
                    )
                )
                result.success(mapTransactionResult(transactionResult))
            } catch (e: Exception) {
                resolveTransactionError(result, e)
            }
        }
    }

    private fun handleGetTransaction(call: MethodCall, result: Result) {
        val transactionToken = call.argument<String>("transactionToken")
        val transactionId = call.argument<String>("transactionId")
        if (transactionToken == null || transactionId == null) {
            result.error("validation", "transactionToken and transactionId are required", null)
            return
        }
        val options = call.argument<Map<String, Any?>>("options") ?: emptyMap()
        scope.launch {
            try {
                val transactionResult = DiditSdk.getTransaction(
                    transactionToken = transactionToken,
                    transactionId = transactionId,
                    options = DiditTransactionOptions(baseUrl = options["baseUrl"] as? String)
                )
                result.success(mapTransactionResult(transactionResult))
            } catch (e: Exception) {
                resolveTransactionError(result, e)
            }
        }
    }

    private fun parseTransactionPayload(txnId: String, map: Map<String, Any?>) =
        DiditTransactionPayload(
            txnId = txnId,
            txnDate = map["txnDate"] as? String,
            zoneId = map["zoneId"] as? String,
            type = map["type"] as? String,
            info = subMap(map, "info")?.let(::parseTransactionInfo),
            subject = subMap(map, "subject")?.let(::parseTransactionParticipant),
            counterparty = subMap(map, "counterparty")?.let(::parseTransactionParticipant),
            props = subMap(map, "props"),
            travelRule = subMap(map, "travelRule")?.let(::parseTravelRule),
            includeCryptoScreening = map["includeCryptoScreening"] as? Boolean
        )

    private fun parseTransactionInfo(map: Map<String, Any?>) = DiditTransactionInfo(
        direction = map["direction"] as? String,
        amount = (map["amount"] as? Number)?.toDouble(),
        currency = map["currency"] as? String,
        currencyType = map["currencyType"] as? String,
        amountInDefaultCurrency = (map["amountInDefaultCurrency"] as? Number)?.toDouble(),
        defaultCurrencyCode = map["defaultCurrencyCode"] as? String,
        paymentDetails = map["paymentDetails"] as? String,
        paymentTxnId = map["paymentTxnId"] as? String,
        type = map["type"] as? String,
        cryptoParams = subMap(map, "cryptoParams")
    )

    private fun parseTransactionParticipant(map: Map<String, Any?>) = DiditTransactionParticipant(
        type = map["type"] as? String,
        externalUserId = map["externalUserId"] as? String,
        fullName = map["fullName"] as? String,
        firstName = map["firstName"] as? String,
        lastName = map["lastName"] as? String,
        dob = map["dob"] as? String,
        address = subMap(map, "address"),
        institutionInfo = subMap(map, "institutionInfo"),
        device = subMap(map, "device"),
        paymentMethod = subMap(map, "paymentMethod")?.let {
            DiditTransactionPaymentMethod(
                type = it["type"] as? String,
                accountId = it["accountId"] as? String,
                issuingCountry = it["issuingCountry"] as? String
            )
        }
    )

    private fun parseTravelRule(map: Map<String, Any?>) = DiditTravelRule(
        status = map["status"] as? String,
        protocol = map["protocol"] as? String,
        required = map["required"] as? Boolean,
        obligationsCount = (map["obligationsCount"] as? Number)?.toInt(),
        originatorData = subMap(map, "originatorData"),
        beneficiaryData = subMap(map, "beneficiaryData"),
        metadata = subMap(map, "metadata")
    )

    private fun subMap(map: Map<String, Any?>, key: String): Map<String, Any?>? =
        (map[key] as? Map<*, *>)?.entries?.associate { it.key.toString() to it.value }

    private fun mapTransactionResult(result: DiditTransactionResult): Map<String, Any?> {
        val map = mutableMapOf<String, Any?>("transactionId" to result.transactionId)
        result.status?.let { map["status"] = it }
        result.travelRuleStatus?.let { map["travelRuleStatus"] = it }
        result.actionRequired?.let { action ->
            val actionMap = mutableMapOf<String, Any?>("type" to action.type)
            action.url?.let { actionMap["url"] = it }
            action.sessionId?.let { actionMap["sessionId"] = it }
            action.sessionToken?.let { actionMap["sessionToken"] = it }
            action.status?.let { actionMap["status"] = it }
            action.widgetSessionId?.let { actionMap["widgetSessionId"] = it }
            action.expiresAt?.let { actionMap["expiresAt"] = it }
            map["actionRequired"] = actionMap
        }
        return map
    }

    private fun resolveTransactionError(result: Result, e: Exception) {
        when (e) {
            is DiditTransactionException.InvalidToken ->
                result.error("invalid_token", e.message, null)
            is DiditTransactionException.ExpiredToken ->
                result.error("expired_token", e.message, null)
            is DiditTransactionException.Validation ->
                result.error("validation", e.message, e.fieldErrors)
            is DiditTransactionException.Network ->
                result.error("network", e.message, null)
            else ->
                result.error("network", e.message ?: "Transaction request failed.", null)
        }
    }
}
