plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.persmon.akatabo"
    // flutter_local_notifications 23 needs compileSdk 37. targetSdk stays at the
    // Flutter default (36), which is what Google Play requires from 31 August 2026.
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Needed by flutter_local_notifications (java.time on older Android).
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.persmon.akatabo"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // LAUNCH BLOCKER: the owner's release signing key is not set up yet.
            // Until it is, release builds are signed with the debug key and must not be published.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
    // AppCompat theme for the fallback fingerprint dialog used by local_auth.
    implementation("androidx.appcompat:appcompat:1.8.0")
}

flutter {
    source = "../.."
}
