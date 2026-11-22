package me.didit.sdk.sdk_flutter

import android.app.Activity
import me.didit.sdk.Configuration

/**
 * What the plugin needs from a Bank Link, independent of the native SDK
 * version it is built against.
 *
 * The wrapper adds no flow of its own: the native SDK owns every screen, the
 * copy and the state machine of a link, and this interface is only the seam
 * between that flow and the method and event channels. [BankLinkWire] holds
 * the two shapes that cross the seam, so the mapping Dart depends on is
 * compiled and tested even while the released native AAR does not carry Bank
 * Link yet.
 *
 * Which implementation the plugin gets is chosen at build time by
 * `newBankLinkBridge()`: `src/bankLinkOff/kotlin` answers [UnavailableBankLinkBridge]
 * (the default, for an AAR without Bank Link) and `src/bankLinkOn/kotlin` hands
 * the call to the native SDK. `-PdiditSdkBankLink=true` is the one switch the
 * native pin flips.
 */
internal interface BankLinkBridge {
    /**
     * Opens a link. Returns `false` when this native SDK cannot present one, in
     * which case no callback is ever invoked.
     */
    fun present(
        activity: Activity,
        token: String,
        configuration: Configuration?,
        onEvent: (BankLinkWire.Event) -> Unit,
        onResult: (BankLinkWire.Outcome) -> Unit
    ): Boolean

    /**
     * Picks up a link whose bank hop outlived the app. Returns `false` when
     * there is nothing to resume.
     */
    fun resume(
        activity: Activity,
        onEvent: (BankLinkWire.Event) -> Unit,
        onResult: (BankLinkWire.Outcome) -> Unit
    ): Boolean

    /** `true` when [url] was a Bank Link return. The address reaches the native SDK unchanged. */
    fun handleReturn(url: String): Boolean
}

/**
 * The two messages of the Bank Link channels, in the exact shape Dart reads.
 *
 * Result keys: `type` (`success` / `exit`), `linkId`, `connectionId`,
 * `checkId`, `reason`, `step`, `resumed`. Event keys: `name` and `data`, with
 * the native snake_case payload passed through untouched. Ids only: nothing
 * here invents a field, and no token, name or account number has a place.
 */
internal object BankLinkWire {

    sealed class Outcome {
        abstract fun toMap(): Map<String, Any?>

        data class Success(
            val linkId: String,
            val connectionId: String?,
            val checkId: String?,
            val resumed: Boolean
        ) : Outcome() {
            override fun toMap(): Map<String, Any?> = mapOf(
                "type" to "success",
                "linkId" to linkId,
                "connectionId" to connectionId,
                "checkId" to checkId,
                "resumed" to resumed
            )
        }

        data class Exit(
            val reason: String,
            val step: String?,
            val resumed: Boolean
        ) : Outcome() {
            override fun toMap(): Map<String, Any?> = mapOf(
                "type" to "exit",
                "reason" to reason,
                "step" to step,
                "resumed" to resumed
            )
        }
    }

    data class Event(
        val name: String,
        val data: Map<String, Any?>
    ) {
        fun toMap(): Map<String, Any?> = mapOf("name" to name, "data" to data)
    }
}

/**
 * The bridge of an AAR that does not carry Bank Link yet: opening a link
 * answers `false` (Dart reads it as a `failed` exit), there is nothing to
 * resume, and no address is a return. The native call sites live in
 * [NativeBankLinkBridge].
 */
internal class UnavailableBankLinkBridge : BankLinkBridge {
    override fun present(
        activity: Activity,
        token: String,
        configuration: Configuration?,
        onEvent: (BankLinkWire.Event) -> Unit,
        onResult: (BankLinkWire.Outcome) -> Unit
    ): Boolean = false

    override fun resume(
        activity: Activity,
        onEvent: (BankLinkWire.Event) -> Unit,
        onResult: (BankLinkWire.Outcome) -> Unit
    ): Boolean = false

    override fun handleReturn(url: String): Boolean = false
}
