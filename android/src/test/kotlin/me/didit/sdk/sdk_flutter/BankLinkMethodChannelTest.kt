package me.didit.sdk.sdk_flutter

import android.app.Activity
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.setMain
import kotlin.test.AfterTest
import kotlin.test.BeforeTest
import kotlin.test.Test
import kotlin.test.assertEquals

/*
 * Bank Link on the Android plugin. The wrapper adds no flow of its own - every
 * screen, the copy and the state machine are native - so these tests pin the two
 * things that cross the channel and belong to this repository: the answers Dart
 * reads as a BankLinkResult, and that an address is never re-parsed.
 *
 * Run them with `./gradlew :didit_sdk:testDebugUnitTest` from example/android.
 */
@OptIn(ExperimentalCoroutinesApi::class)
internal class BankLinkMethodChannelTest {
    private val hostActivity = mockk<Activity>()
    private val result = mockk<MethodChannel.Result>(relaxed = true)
    private val delivered = mutableListOf<Any?>()
    private val errors = mutableListOf<String>()
    private lateinit var plugin: SdkFlutterPlugin

    @BeforeTest
    fun setUp() {
        Dispatchers.setMain(UnconfinedTestDispatcher())
        every { result.success(any()) } answers { delivered += firstArg<Any?>() }
        every { result.error(any(), any(), any()) } answers { errors += firstArg<String>() }

        plugin = SdkFlutterPlugin()
        plugin.onAttachedToActivity(mockk<ActivityPluginBinding> {
            every { activity } returns hostActivity
        })
    }

    @AfterTest
    fun tearDown() {
        Dispatchers.resetMain()
    }

    private fun call(method: String, arguments: Map<String, Any?>?) =
        plugin.onMethodCall(MethodCall(method, arguments), result)

    @Test
    fun presentBankLink_withoutToken_answersInvalidArgument() {
        call("presentBankLink", mapOf("options" to mapOf("config" to emptyMap<String, Any>())))

        assertEquals(listOf("INVALID_ARGUMENT"), errors)
        assertEquals<List<Any?>>(emptyList(), delivered)
    }

    @Test
    fun presentBankLink_answersUnavailableUntilTheNativeSdkCarriesBankLink() {
        call("presentBankLink", mapOf("token" to "blt_Hs8Pa4Rb6Ye0Gf2Jc7Qm3Zx9Vd2Lc5W"))

        // Dart reads this as a `failed` exit, never as an uncaught error.
        assertEquals(listOf("unavailable"), errors)
        assertEquals<List<Any?>>(emptyList(), delivered)
    }

    @Test
    fun resumeBankLink_answersNullWhenNoLinkIsKept() {
        call("resumeBankLink", null)

        assertEquals(1, delivered.size)
        assertEquals(null, delivered.single())
        assertEquals<List<String>>(emptyList(), errors)
    }

    /** A fake native module that keeps the last callbacks, like the native SDK. */
    private class FakeBridge(var resumes: Boolean) : BankLinkBridge {
        var resumeCalls = 0
        private var onResult: ((BankLinkWire.Outcome) -> Unit)? = null

        fun finish(outcome: BankLinkWire.Outcome) {
            onResult?.invoke(outcome)
        }

        override fun present(
            activity: Activity,
            token: String,
            configuration: me.didit.sdk.Configuration?,
            onEvent: (BankLinkWire.Event) -> Unit,
            onResult: (BankLinkWire.Outcome) -> Unit
        ): Boolean {
            this.onResult = onResult
            return true
        }

        override fun resume(
            activity: Activity,
            configuration: Configuration?,
            onEvent: (BankLinkWire.Event) -> Unit,
            onResult: (BankLinkWire.Outcome) -> Unit
        ): Boolean {
            resumeCalls++
            this.onResult = onResult
            return resumes
        }

        override fun handleReturn(url: String): Boolean = false
    }

    @Test
    fun resumeBankLink_whileALinkIsOpen_answersNullWithoutReachingNative() {
        val bridge = FakeBridge(resumes = true)
        plugin.bankLinkBridge = bridge
        call("presentBankLink", mapOf("token" to "blt_Hs8Pa4Rb6Ye0Gf2Jc7Qm3Zx9Vd2Lc5W"))

        call("resumeBankLink", null)
        bridge.finish(BankLinkWire.Outcome.Exit(reason = "closed", step = "consent", resumed = false))

        // The resume did not take the open link's callbacks: it answered null,
        // and the presenting call got its own result.
        assertEquals(0, bridge.resumeCalls)
        assertEquals(2, delivered.size)
        assertEquals(null, delivered[0])
        assertEquals("closed", (delivered[1] as Map<*, *>)["reason"])
    }

    @Test
    fun resumeBankLink_thatFoundNothing_isNotAnsweredAgainByALateCallback() {
        val bridge = FakeBridge(resumes = false)
        plugin.bankLinkBridge = bridge

        call("resumeBankLink", null)
        bridge.finish(BankLinkWire.Outcome.Exit(reason = "failed", step = null, resumed = true))

        assertEquals<List<Any?>>(listOf(null), delivered)
        assertEquals<List<String>>(emptyList(), errors)
    }

    @Test
    fun handleBankLinkReturn_withoutAddress_answersInvalidArgument() {
        call("handleBankLinkReturn", emptyMap<String, Any?>())

        assertEquals(listOf("INVALID_ARGUMENT"), errors)
    }

    @Test
    fun handleBankLinkReturn_answersWhetherTheAddressWasABankLinkReturn() {
        call(
            "handleBankLinkReturn",
            mapOf(
                "url" to
                    "https://app.example.com/bank/return" +
                    "?didit_resume=rsc_0b9c4f1e6a2d4e8b9f317c5d2e1a8b40" +
                    ".7Hq3Zx9Wd2Lm5Tn8Vc1Ks4Pa6Rb0Uv3"
            )
        )

        assertEquals(listOf<Any?>(false), delivered)
        assertEquals<List<String>>(emptyList(), errors)
    }
}
