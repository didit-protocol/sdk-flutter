package me.didit.sdk.sdk_flutter

import android.app.Activity
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.mockk.every
import io.mockk.mockk
import me.didit.sdk.Configuration
import kotlin.test.BeforeTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue

/*
 * The native side of the wrapper: the plugin hands a link to the native SDK,
 * forwards every event to the `didit_sdk/bank_link_events` channel, and settles
 * each Dart call with exactly one answer. The native module is a fake here, so
 * the seam is tested without an AAR that carries Bank Link.
 *
 * Run these with `./gradlew :didit_sdk:testDebugUnitTest` from example/android.
 */
internal class BankLinkBridgeTest {

    private val hostActivity = mockk<Activity>()
    private val result = mockk<MethodChannel.Result>(relaxed = true)
    private val delivered = mutableListOf<Any?>()
    private val errors = mutableListOf<String>()
    private val events = mutableListOf<Any?>()
    private val bridge = FakeBankLinkBridge()
    private lateinit var plugin: SdkFlutterPlugin

    @BeforeTest
    fun setUp() {
        every { result.success(any()) } answers { delivered += firstArg<Any?>() }
        every { result.error(any(), any(), any()) } answers { errors += firstArg<String>() }

        val sink = mockk<EventChannel.EventSink>(relaxed = true)
        every { sink.success(any()) } answers { events += firstArg<Any?>() }

        plugin = SdkFlutterPlugin()
        plugin.bankLinkEvents = sink
        plugin.bankLinkBridge = bridge
        plugin.onAttachedToActivity(mockk<ActivityPluginBinding> {
            every { activity } returns hostActivity
        })
    }

    private fun call(method: String, arguments: Map<String, Any?>?) =
        plugin.onMethodCall(MethodCall(method, arguments), result)

    @Test
    fun presentForwardsTheTokenAndConfigurationToTheNativeSdk() {
        call(
            "presentBankLink",
            mapOf(
                "token" to "blt_Hs8Pa4Rb6Ye0Gf2Jc7Qm3Zx9Vd2Lc5W",
                "options" to mapOf("config" to mapOf("languageCode" to "es"))
            )
        )

        assertEquals(
            listOf("blt_Hs8Pa4Rb6Ye0Gf2Jc7Qm3Zx9Vd2Lc5W"),
            bridge.presentedTokens
        )
        assertEquals("es", bridge.presentedConfigurations.single()?.languageLocale?.code)
        assertEquals(hostActivity, bridge.presentedFrom.single())
        assertEquals<List<Any?>>(emptyList(), delivered)
    }

    @Test
    fun everyEventReachesTheChannelWithItsNameAndPayloadUntouched() {
        call("presentBankLink", mapOf("token" to "blt_Hs8Pa4Rb6Ye0Gf2Jc7Qm3Zx9Vd2Lc5W"))

        bridge.emit(
            BankLinkWire.Event(
                "opened",
                mapOf("link_id" to "link-1", "mode" to "connect", "access" to "ongoing")
            )
        )
        bridge.emit(BankLinkWire.Event("exit", mapOf("reason" to "closed", "link_id" to "link-1")))

        assertEquals(
            listOf(
                mapOf(
                    "name" to "opened",
                    "data" to mapOf("link_id" to "link-1", "mode" to "connect", "access" to "ongoing")
                ),
                mapOf(
                    "name" to "exit",
                    "data" to mapOf("reason" to "closed", "link_id" to "link-1")
                )
            ),
            events
        )
    }

    @Test
    fun aSuccessSettlesDartWithTheIdsAndTheResumedFlag() {
        call("presentBankLink", mapOf("token" to "blt_Hs8Pa4Rb6Ye0Gf2Jc7Qm3Zx9Vd2Lc5W"))

        bridge.finish(
            BankLinkWire.Outcome.Success(
                linkId = "link-1",
                connectionId = "connection-1",
                checkId = "check-1",
                resumed = true
            )
        )

        assertEquals(
            listOf(
                mapOf(
                    "type" to "success",
                    "linkId" to "link-1",
                    "connectionId" to "connection-1",
                    "checkId" to "check-1",
                    "resumed" to true
                )
            ),
            delivered
        )
        assertEquals<List<String>>(emptyList(), errors)
    }

    @Test
    fun everyExitReasonReachesDartAsItsWireName() {
        for (reason in listOf("closed", "cancelled", "bank_unavailable", "expired", "failed")) {
            setUp()
            delivered.clear()
            events.clear()

            call("presentBankLink", mapOf("token" to "blt_Hs8Pa4Rb6Ye0Gf2Jc7Qm3Zx9Vd2Lc5W"))
            bridge.finish(BankLinkWire.Outcome.Exit(reason, "bank_hop", false))

            assertEquals(
                listOf(
                    mapOf(
                        "type" to "exit",
                        "reason" to reason,
                        "step" to "bank_hop",
                        "resumed" to false
                    )
                ),
                delivered,
                reason
            )
        }
    }

    @Test
    fun aSecondResultIsDroppedSoDartSettlesOnce() {
        call("presentBankLink", mapOf("token" to "blt_Hs8Pa4Rb6Ye0Gf2Jc7Qm3Zx9Vd2Lc5W"))

        bridge.finish(BankLinkWire.Outcome.Exit("closed", "consent", false))
        bridge.finish(BankLinkWire.Outcome.Exit("failed", null, false))

        assertEquals(1, delivered.size)
    }

    @Test
    fun aSecondLinkWhileOneIsOpenFailsWithoutReachingTheNativeSdk() {
        call("presentBankLink", mapOf("token" to "blt_Hs8Pa4Rb6Ye0Gf2Jc7Qm3Zx9Vd2Lc5W"))
        call("presentBankLink", mapOf("token" to "blt_Hs8Pa4Rb6Ye0Gf2Jc7Qm3Zx9Vd2Lc5W"))

        assertEquals(1, bridge.presentedTokens.size)
        assertEquals(
            mapOf(
                "type" to "exit",
                "reason" to "failed",
                "step" to null,
                "resumed" to false
            ),
            delivered.single()
        )
    }

    @Test
    fun resumeAnswersNullWhenTheNativeSdkHasNothingPending() {
        call("resumeBankLink", null)

        assertEquals(listOf<Any?>(null), delivered)
        assertEquals<List<String>>(emptyList(), errors)
    }

    @Test
    fun resumeAnswersTheReplayedResultWithItsResumedFlag() {
        bridge.resumes = true
        bridge.resumeOutcome = BankLinkWire.Outcome.Success(
            linkId = "link-1",
            connectionId = null,
            checkId = null,
            resumed = true
        )

        call("resumeBankLink", null)

        assertEquals(
            listOf(
                mapOf(
                    "type" to "success",
                    "linkId" to "link-1",
                    "connectionId" to null,
                    "checkId" to null,
                    "resumed" to true
                )
            ),
            delivered
        )
    }

    @Test
    fun aReturnAddressReachesTheNativeHandlerByteForByte() {
        bridge.handled = true
        val url = "https://app.example.com/bank/return" +
            "?didit_resume=rsc_0b9c4f1e6a2d4e8b9f317c5d2e1a8b40" +
            ".7Hq3Zx9Wd2Lm5Tn8Vc1Ks4Pa6Rb0Uv3"

        call("handleBankLinkReturn", mapOf("url" to url))

        assertEquals(listOf(url), bridge.returnAddresses)
        assertEquals(listOf<Any?>(true), delivered)
    }

    @Test
    fun anAddressThatIsNotABankReturnIsReportedAsSuch() {
        call("handleBankLinkReturn", mapOf("url" to "https://app.example.com/other"))

        assertEquals(listOf<Any?>(false), delivered)
    }

    @Test
    fun theUnavailableBridgeLeavesDartWithAFailedExit() {
        plugin.bankLinkBridge = UnavailableBankLinkBridge()

        call("presentBankLink", mapOf("token" to "blt_Hs8Pa4Rb6Ye0Gf2Jc7Qm3Zx9Vd2Lc5W"))

        assertEquals(listOf("unavailable"), errors)
        assertEquals<List<Any?>>(emptyList(), delivered)
    }

    // The service pins every identifier it hands to a client in one file. The
    // wrapper applies no pattern of its own, so every example must reach the
    // native SDK unchanged - a resume code keeps its dot, a token keeps its
    // prefix. The native validators are walked by mobile-sdks' own suite.
    @Test
    fun everyFormatExampleIsForwardedUnchanged() {
        val examples = formatsExamples()
        assertTrue(examples.size >= 14, "formats.json: ${examples.size} examples")

        for (example in examples) {
            setUp()
            delivered.clear()
            events.clear()
            bridge.presentedTokens.clear()

            call("presentBankLink", mapOf("token" to example))
            assertEquals(listOf(example), bridge.presentedTokens, example)

            bridge.handled = true
            val url = "https://app.example.com/bank/return?didit_resume=$example"
            call("handleBankLinkReturn", mapOf("url" to url))
            assertEquals(listOf(url), bridge.returnAddresses, example)
        }
    }

    private fun formatsExamples(): List<String> {
        val fixture = javaClass.classLoader
            ?.getResourceAsStream("bank_link_contract/formats.json")
            ?.bufferedReader()
            ?.readText()
            ?: error("bank_link_contract/formats.json is missing from the test resources")
        return Regex("\"example\"\\s*:\\s*\"([^\"]+)\"")
            .findAll(fixture)
            .map { it.groupValues[1] }
            .toList()
    }

    private class FakeBankLinkBridge : BankLinkBridge {
        val presentedTokens = mutableListOf<String>()
        val presentedConfigurations = mutableListOf<Configuration?>()
        val presentedFrom = mutableListOf<Activity>()
        val returnAddresses = mutableListOf<String>()
        var resumes = false
        var handled = false
        var resumeOutcome: BankLinkWire.Outcome? = null

        private var onEvent: ((BankLinkWire.Event) -> Unit)? = null
        private var onResult: ((BankLinkWire.Outcome) -> Unit)? = null

        fun emit(event: BankLinkWire.Event) {
            onEvent?.invoke(event)
        }

        fun finish(outcome: BankLinkWire.Outcome) {
            onResult?.invoke(outcome)
        }

        override fun present(
            activity: Activity,
            token: String,
            configuration: Configuration?,
            onEvent: (BankLinkWire.Event) -> Unit,
            onResult: (BankLinkWire.Outcome) -> Unit
        ): Boolean {
            presentedTokens += token
            presentedConfigurations += configuration
            presentedFrom += activity
            this.onEvent = onEvent
            this.onResult = onResult
            return true
        }

        override fun resume(
            activity: Activity,
            onEvent: (BankLinkWire.Event) -> Unit,
            onResult: (BankLinkWire.Outcome) -> Unit
        ): Boolean {
            this.onEvent = onEvent
            this.onResult = onResult
            resumeOutcome?.let { onResult(it) }
            return resumes
        }

        override fun handleReturn(url: String): Boolean {
            returnAddresses += url
            return handled
        }
    }
}
