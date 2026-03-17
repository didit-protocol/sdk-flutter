# ── Didit SDK Consumer ProGuard / R8 Rules ──────────────────────────────────
# These rules mirror the native AAR's consumer rules. Flutter's Gradle
# integration does not always propagate proguard.txt from transitive AAR
# dependencies, so the Flutter plugin must re-declare them here.
# ─────────────────────────────────────────────────────────────────────────────

# ── SDK Classes ─────────────────────────────────────────────────────────────
-keep class me.didit.sdk.** { *; }
-keepclassmembers class me.didit.sdk.** { *; }

# ── Type Information (required for Gson/Retrofit generic type resolution) ───
-keepattributes Signature
-keepattributes Exceptions
-keepattributes InnerClasses
-keepattributes EnclosingMethod
-keepattributes *Annotation*

# ── Gson ────────────────────────────────────────────────────────────────────
-keep class com.google.gson.** { *; }
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keepclassmembers class * extends com.google.gson.reflect.TypeToken {
    <fields>;
    <methods>;
}
-keepclassmembers,allowobfuscation class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# ── Retrofit ────────────────────────────────────────────────────────────────
-keep,allowobfuscation,allowshrinking interface retrofit2.Call
-keep,allowobfuscation,allowshrinking class retrofit2.Response
-keep,allowobfuscation,allowshrinking class kotlin.coroutines.Continuation
-keepclassmembers,allowshrinking,allowobfuscation interface * {
    @retrofit2.http.* <methods>;
}
-dontwarn retrofit2.**

# ── OkHttp / Okio ──────────────────────────────────────────────────────────
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep class okio.** { *; }

# ── Kotlin Coroutines ───────────────────────────────────────────────────────
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}
-keepclassmembers class kotlinx.coroutines.** {
    volatile <fields>;
}

# ── NFC ePassport Libraries ─────────────────────────────────────────────────
-keep class org.jmrtd.** { *; }
-dontwarn org.jmrtd.**

-keep class net.sf.scuba.** { *; }
-dontwarn net.sf.scuba.**

-keep class org.bouncycastle.** { *; }
-dontwarn org.bouncycastle.**

# ── Google Flogger (logging framework used by MediaPipe) ────────────────────
# Flogger's FluentLogger uses stack-walking to locate the calling class.
# R8 must preserve its class names to prevent IllegalStateException.
-keep class com.google.common.flogger.** { *; }
-keepnames class com.google.common.flogger.** { *; }
-dontwarn com.google.common.flogger.**

# ── MediaPipe ───────────────────────────────────────────────────────────────
# MediaPipe's Graph class uses stack-walking to find the caller for native
# library loading. All framework classes and their names must be preserved.
-keep class com.google.mediapipe.** { *; }
-keepnames class com.google.mediapipe.** { *; }
-keep class com.google.mediapipe.framework.** { *; }
-dontwarn com.google.mediapipe.**

# Protobuf Lite (used internally by MediaPipe)
-keep class com.google.protobuf.** { *; }
-dontwarn com.google.protobuf.**
