package me.didit.sdk.sdk_flutter

import android.app.Activity
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.mockk.every
import io.mockk.isNull
import io.mockk.mockk
import kotlin.test.BeforeTest
import kotlin.test.Test
import kotlin.test.assertEquals

/*
 * Bank Link on the Android plugin. The wrapper adds no flow of its own - every
 * screen, the copy and the state machine are native - so these tests pin the two
 * things that cross the channel and belong to this repository: the answers the
 * Dart side reads as a BankLinkResult, and that an address is never re-parsed.
 *
 * Run them with `./gradlew :didit_sdk:testDebugUnitTest` from example/android.
 */
internal class BankLinkMethodChannelTest {
    private val hostActivity = mockk<Activity>()
    private val result = mockk<MethodChannel.Result>(relaxed = true)
    private val delivered = mutableListOf<Any?>()
    private val errors = mutableListOf<String>()
    private lateinit var plugin: SdkFlutterPlugin

    @BeforeTest
    fun setUp() {
        every { result.success(any()) } answers { delivered += firstArg<Any?>() }
        every { result.success(isNull()) } answers { delivered += null }
        every { result.error(any(), any(), any()) } answers { errors += firstArg<String>() }

        plugin = SdkFlutterPlugin()
        plugin.onAttachedToActivity(mockk<ActivityPluginBinding> {
            every { activity } returns hostActivity
        })
    }

    private fun call(method: String, arguments: Map<String, Any?>?) =
        plugin.onMethodCall(MethodCall(method, arguments), result)

    @Test
    fun presentBankLink_withoutToken_answersInvalidArgument() {
        call("presentBankLink", mapOf("options" to mapOf("config" to mapOf("languageCode" to "es"))))

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

        assertEquals(listOf<Any?>(null), delivered)
        assertEquals<List<String>>(emptyList(), errors)
    }

    @Test
    fun handleBankLinkReturn_withoutAddress_answersInvalidArgument() {
        call("handleBankLinkReturn", mapOf<String, Any?>())

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
