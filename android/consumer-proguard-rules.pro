# Didit SDK — consumer ProGuard/R8 rules
# These rules are automatically applied to apps that depend on this library.

# Keep all Didit SDK classes (models, API, UI)
-keep class me.didit.sdk.** { *; }
-keepclassmembers class me.didit.sdk.** { *; }

# Preserve generic type information needed for JSON deserialization
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# Kotlin coroutines
-keep class kotlinx.coroutines.** { *; }
-dontwarn kotlinx.coroutines.**

# OkHttp / Retrofit (common networking deps)
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn retrofit2.**
-keep class retrofit2.** { *; }
-keepclassmembers,allowobfuscation class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# Gson
-keep class com.google.gson.** { *; }
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# BouncyCastle (NFC cryptography)
-keep class org.bouncycastle.** { *; }
-dontwarn org.bouncycastle.**
