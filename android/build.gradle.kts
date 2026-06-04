group = "me.didit.sdk.sdk_flutter"
version = "1.0-SNAPSHOT"

val diditSdkAndroidVersion = "4.0.3"
val diditSdkAndroidVariant = (
    rootProject.findProperty("diditSdkAndroidVariant")
        ?: findProperty("diditSdkAndroidVariant")
        ?: "all"
    ).toString().lowercase()
val diditSdkAndroidArtifact = when (diditSdkAndroidVariant) {
    "all" -> "didit-sdk"
    "core" -> "didit-sdk-core"
    "autodetection" -> "didit-sdk-autodetection"
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
    }
}

plugins {
    id("com.android.library")
    id("kotlin-android")
}

android {
    namespace = "me.didit.sdk.sdk_flutter"

    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
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

dependencies {
    implementation("me.didit:$diditSdkAndroidArtifact:$diditSdkAndroidVersion")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.7.3")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")

    testImplementation("org.jetbrains.kotlin:kotlin-test")
    testImplementation("org.mockito:mockito-core:5.0.0")
}
