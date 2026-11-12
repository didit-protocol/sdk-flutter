group = "me.didit.auth.flutter"
version = "1.0-SNAPSHOT"

// The one place that pins the native DiditAuth release (me.didit:didit-auth).
// ios/didit_auth.podspec and ios/didit_auth/Package.swift pin the same release;
// test/native_pin_test.dart keeps the three equal.
val diditAuthNativeVersion = "4.14.7"

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

// Resolve the native DiditAuth AAR from Didit's public Maven repository. It is
// added to every project of the build, the app included, because the app
// resolves this plugin's dependencies at run time. The same repository serves
// the didit_sdk plugin, so one app can use both.
rootProject.allprojects {
    repositories {
        maven {
            url = uri("https://raw.githubusercontent.com/didit-protocol/sdk-android/main/repository")
            content { includeGroup("me.didit") }
        }
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
    namespace = "me.didit.auth.flutter"

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
        // The same floor as the native me.didit:didit-auth artifact.
        minSdk = 23
    }

    testOptions {
        unitTests {
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
    // Brings didit-signals only, not the verification SDK.
    implementation("me.didit:didit-auth:$diditAuthNativeVersion")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")

    // KGP infers the JUnit 5 flavour of kotlin-test; built-in Kotlin does not.
    testImplementation("org.jetbrains.kotlin:kotlin-test-junit5")
    testRuntimeOnly("org.junit.platform:junit-platform-launcher")
    // The Android stub of org.json throws in JVM unit tests.
    testImplementation("org.json:json:20240303")
}
