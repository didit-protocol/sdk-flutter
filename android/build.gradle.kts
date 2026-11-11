group = "me.didit.sdk.sdk_flutter"
version = "1.0-SNAPSHOT"

val diditSdkAndroidVersion = "4.14.6"
val diditSdkAndroidVariant = (
    rootProject.findProperty("diditSdkAndroidVariant")
        ?: findProperty("diditSdkAndroidVariant")
        ?: "all"
    ).toString().lowercase()
val diditSdkAndroidArtifact = when (diditSdkAndroidVariant) {
    "all" -> "didit-sdk"
    "core" -> "didit-sdk-core"
    // Deprecated and identical to core since native 4.10.0 (didit-sdk-autodetection is empty).
    "autodetection" -> "didit-sdk-core"
    "nfc" -> "didit-sdk-nfc"
    else -> error(
        "Invalid diditSdkAndroidVariant '$diditSdkAndroidVariant'. " +
            "Supported values: all, core, autodetection, nfc."
    )
}
val diditSdkAndroidRepositoryUrl = (
    rootProject.findProperty("diditSdkAndroidRepositoryUrl")
        ?: findProperty("diditSdkAndroidRepositoryUrl")
    )?.toString()

buildscript {
    val kotlinVersion = "2.2.20"
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath("com.android.tools.build:gradle:8.11.1")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlinVersion")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Resolve the native DiditSDK Android AAR from the public GitHub Maven repository.
rootProject.allprojects {
    repositories {
        diditSdkAndroidRepositoryUrl?.let {
            maven { url = uri(it) }
        }
        maven { url = uri("https://raw.githubusercontent.com/didit-protocol/sdk-android/main/repository") }
        maven { url = uri("https://jitpack.io") }
    }
}

plugins {
    id("com.android.library")
}

// AGP 9+ compiles Kotlin itself ("built-in Kotlin") and rejects the Kotlin
// Gradle Plugin, and Flutter warns about plugins that declare it. Apply KGP only
// where built-in Kotlin is off: AGP 8, or AGP 9 with android.builtInKotlin=false
// (the same rule Flutter's Gradle plugin uses).
val builtInKotlin = androidComponents.pluginVersion.major >= 9 &&
    (providers.gradleProperty("android.builtInKotlin").orNull?.toBoolean() ?: true)
if (!builtInKotlin) {
    apply(plugin = "kotlin-android")
}

android {
    namespace = "me.didit.sdk.sdk_flutter"

    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    sourceSets {
        getByName("main") {
            java.srcDirs("src/main/kotlin")
        }
        getByName("test") {
            java.srcDirs("src/test/kotlin")
        }
    }

    defaultConfig {
        minSdk = 23
        consumerProguardFiles("consumer-proguard-rules.pro")
        if (diditSdkAndroidVariant == "all" || diditSdkAndroidVariant == "nfc") {
            consumerProguardFiles("consumer-proguard-rules-nfc.pro")
        }
    }

    testOptions {
        unitTests {
            isIncludeAndroidResources = true
            all {
                it.useJUnitPlatform()

                it.outputs.upToDateWhen { false }

                it.testLogging {
                    events("passed", "skipped", "failed", "standardOut", "standardError")
                    showStandardStreams = true
                }
            }
        }
    }
}

// The `kotlin` extension exists with both KGP and built-in Kotlin, unlike
// android.kotlinOptions, which only KGP adds.
extensions.configure<org.jetbrains.kotlin.gradle.dsl.KotlinAndroidProjectExtension>("kotlin") {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}

dependencies {
    implementation("me.didit:$diditSdkAndroidArtifact:$diditSdkAndroidVersion")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.7.3")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")

    // KGP infers the JUnit 5 flavour of kotlin-test; built-in Kotlin does not.
    testImplementation("org.jetbrains.kotlin:kotlin-test-junit5")
    testRuntimeOnly("org.junit.platform:junit-platform-launcher")
    testImplementation("io.mockk:mockk:1.14.11")
    testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.8.1")
}
