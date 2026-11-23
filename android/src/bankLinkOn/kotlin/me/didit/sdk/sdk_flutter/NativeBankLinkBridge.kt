package me.didit.sdk.sdk_flutter

import android.app.Activity
import android.net.Uri
import me.didit.sdk.Configuration
import me.didit.sdk.DiditSdk
import me.didit.sdk.features.bank.link.BankLinkResult

/**
 * The hand-off into the native Android Bank Link, written against the public
 * API of the Android native issue (`DiditSdk.presentBankLink(activity, token,
 * configuration, onEvent, onResult)`, sealed `BankLinkResult.Success`/`.Exit`,
 * `DiditSdk.resumeBankLink(activity)`, `DiditSdk.handleBankLinkReturn(uri)`).
 *
 * Compiled only with `-PdiditSdkBankLink=true`, which is also the moment the
 * native AAR in `build.gradle.kts` moves to the version that carries Bank Link;
 * the pin aligns the one import that names the sealed result, and CI compiles
 * this file from then on. Until then the plugin ships
 * [UnavailableBankLinkBridge], so nothing here can reach a host by accident.
 *
 * No parsing happens on this side: the token and the return address reach the
 * native SDK byte for byte, and every event and result field is mapped, never
 * re-derived, so a resume code that carries a dot survives the trip.
 */
internal class NativeBankLinkBridge : BankLinkBridge {

    override fun present(
        activity: Activity,
        token: String,
        configuration: Configuration?,
        onEvent: (BankLinkWire.Event) -> Unit,
        onResult: (BankLinkWire.Outcome) -> Unit
    ): Boolean {
        return DiditSdk.presentBankLink(
            activity = activity,
            token = token,
            configuration = configuration,
            onEvent = { event -> onEvent(BankLinkWire.Event(event.name.wire, event.payload)) },
            onResult = { result -> onResult(result.toWire()) }
        )
    }

    override fun resume(
        activity: Activity,
        onEvent: (BankLinkWire.Event) -> Unit,
        onResult: (BankLinkWire.Outcome) -> Unit
    ): Boolean = DiditSdk.resumeBankLink(
        activity = activity,
        onEvent = { event -> onEvent(BankLinkWire.Event(event.name.wire, event.payload)) },
        onResult = { result -> onResult(result.toWire()) }
    )

    override fun handleReturn(url: String): Boolean =
        DiditSdk.handleBankLinkReturn(Uri.parse(url))

    private fun BankLinkResult.toWire(): BankLinkWire.Outcome = when (this) {
        is BankLinkResult.Success -> BankLinkWire.Outcome.Success(
            linkId = success.linkId,
            connectionId = success.connectionId,
            checkId = success.checkId,
            resumed = success.resumed
        )

        is BankLinkResult.Exit -> BankLinkWire.Outcome.Exit(
            reason = exit.reason.wire,
            step = exit.step?.wire,
            resumed = exit.resumed
        )
    }
}
