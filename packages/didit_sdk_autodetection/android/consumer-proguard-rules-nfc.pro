# ── NFC ePassport Libraries ─────────────────────────────────────────────────

-keep class me.didit.sdk.features.nfc.** { *; }
-keepclassmembers class me.didit.sdk.features.nfc.** { *; }

-keep class org.jmrtd.** { *; }
-dontwarn org.jmrtd.**

-keep class net.sf.scuba.** { *; }
-dontwarn net.sf.scuba.**

-keep class org.bouncycastle.** { *; }
-dontwarn org.bouncycastle.**
