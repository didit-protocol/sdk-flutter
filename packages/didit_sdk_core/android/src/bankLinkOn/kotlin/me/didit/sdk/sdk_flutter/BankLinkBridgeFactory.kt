package me.didit.sdk.sdk_flutter

/**
 * The bridge for a native AAR that carries Bank Link. Compiled only when the
 * build passes `-PdiditSdkBankLink=true`, after the native version is pinned.
 */
internal fun newBankLinkBridge(): BankLinkBridge = NativeBankLinkBridge()
