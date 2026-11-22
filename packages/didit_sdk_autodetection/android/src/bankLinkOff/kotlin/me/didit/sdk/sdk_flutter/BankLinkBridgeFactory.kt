package me.didit.sdk.sdk_flutter

/**
 * The bridge for the released native AAR, which does not carry Bank Link yet
 * (mobile-sdks: iOS #419, Android DID-12137). The build selects this directory
 * by default; `-PdiditSdkBankLink=true` compiles `src/bankLinkOn/kotlin`
 * instead, whose factory returns [NativeBankLinkBridge].
 */
internal fun newBankLinkBridge(): BankLinkBridge = UnavailableBankLinkBridge()
