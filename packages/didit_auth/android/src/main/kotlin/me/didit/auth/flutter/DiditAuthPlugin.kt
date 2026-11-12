package me.didit.auth.flutter

import android.app.Activity
import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import me.didit.sdk.auth.DiditAuth
import me.didit.sdk.auth.DiditAuthException

/**
 * Forwards every call of the `didit_auth` channel to native DiditAuth. Its error codes reach Dart
 * unchanged (see [AuthWire]). Sessions and step-up results cross the channel as JSON text.
 */
class DiditAuthPlugin :
    FlutterPlugin,
    MethodCallHandler,
    ActivityAware {

    private var channel: MethodChannel? = null
    private var applicationContext: Context? = null

    // Set only while an Activity is attached; never kept after it detaches.
    private var activity: Activity? = null

    // Calls run on the main thread. Native DiditAuth suspends instead of blocking it.
    private var scope: CoroutineScope? = null

    // One DiditAuth per application, created and read on the main thread only.
    private val instances = mutableMapOf<Pair<String, String>, DiditAuth>()

    // ── FlutterPlugin ────────────────────────────────────────────────────────

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = binding.applicationContext
        scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
        channel = MethodChannel(binding.binaryMessenger, CHANNEL).also { it.setMethodCallHandler(this) }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        scope?.cancel()
        scope = null
        instances.clear()
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
            "signIn" -> forward(call, result) { auth -> AuthWire.sessionJson(auth.signIn(requireActivity())) }
            "signInWithPasskey" -> forward(call, result) { auth ->
                AuthWire.sessionJson(auth.signInWithPasskey(requireActivity()))
            }
            "reauthenticate" -> forward(call, result) { auth ->
                val method = AuthWire.reauthMethod(call.argument<String>("method"))
                AuthWire.sessionJson(auth.reauthenticate(requireActivity(), method))
            }
            "registerPasskey" -> forward(call, result) { auth -> auth.registerPasskey(requireActivity()) }
            "currentSession" -> forward(call, result) { auth ->
                auth.currentSession(call.argument<Boolean>("force") ?: false)?.let(AuthWire::sessionJson)
            }
            "getToken" -> forward(call, result) { auth -> auth.getToken() }
            "signOut" -> forward(call, result) { auth ->
                auth.signOut()
                null
            }
            "stepUp" -> forward(call, result) { auth ->
                val action = AuthWire.stepUpAction(
                    call.argument<String>("action"),
                    call.argument<String>("amount"),
                    call.argument<String>("currency")
                )
                AuthWire.stepUpResultJson(auth.stepUp(requireActivity(), action))
            }
            else -> result.notImplemented()
        }
    }

    /** Runs [block] on the main thread and answers [result] exactly once, with its value or its failure. */
    private fun forward(call: MethodCall, result: Result, block: suspend (DiditAuth) -> Any?) {
        val scope = scope
        if (scope == null) {
            fail(result, DiditAuthException("server_error", "The plugin is detached from the Flutter engine."))
            return
        }
        scope.launch {
            val value = try {
                block(auth(call))
            } catch (e: CancellationException) {
                // The engine detached: nobody is left to answer.
                throw e
            } catch (e: Exception) {
                fail(result, e)
                return@launch
            }
            result.success(value)
        }
    }

    private fun fail(result: Result, error: Throwable) {
        val reply = AuthWire.errorReply(error)
        result.error(reply.code, reply.message, reply.details)
    }

    private fun auth(call: MethodCall): DiditAuth {
        val publishableKey = call.argument<String>("publishableKey")
            ?: throw DiditAuthException("invalid_publishable_key", "publishableKey is required.")
        val redirectUri = call.argument<String>("redirectUri")
            ?: throw DiditAuthException("invalid_redirect_uri", "redirectUri is required.")
        val context = applicationContext
            ?: throw DiditAuthException("server_error", "The plugin is detached from the Flutter engine.")
        return instances.getOrPut(publishableKey to redirectUri) {
            try {
                DiditAuth(context, publishableKey, redirectUri)
            } catch (e: IllegalArgumentException) {
                throw AuthWire.invalidRedirectUri(e)
            }
        }
    }

    /** The Activity in the foreground, read when the call starts; the Custom Tab and passkey prompt need it. */
    private fun requireActivity(): Activity =
        activity ?: throw DiditAuthException("browser_unavailable", "No activity is in the foreground to show the Didit page.")

    private companion object {
        const val CHANNEL = "didit_auth"
    }
}
