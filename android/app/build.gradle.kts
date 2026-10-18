plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties

// Load keystore properties for release signing.
// - key.properties lives at android/key.properties (Gradle rootProject)
// - keystore.jks lives at android/app/ (this module's projectDir)
// Required only when assembling/bundling a Release variant (debug stays unsigned).
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val isReleaseTaskRequested =
    gradle.startParameter.taskNames.any { name ->
        name.contains("Release", ignoreCase = true)
    }

if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
} else if (isReleaseTaskRequested) {
    throw GradleException(
        "Release signing required: missing ${keystorePropertiesFile.path}. " +
            "Copy android/key.properties.example → android/key.properties and point " +
            "storeFile at your keystore under android/app/ (e.g. keystore.jks). " +
            "Debug/profile builds do not need this file.",
    )
}

android {
    namespace = "id.onyet.app.kiblat"
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Required for newer libraries that use Java language APIs and need desugaring
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "id.onyet.app.kiblat"
        minSdk = flutter.minSdkVersion
        targetSdk = 37
        versionCode = flutter.versionCode
        versionName = flutter.versionName

    }

    if (keystorePropertiesFile.exists()) {
        val storeFileName =
            keystoreProperties.getProperty("storeFile", "keystore.jks")
        val releaseStoreFile = layout.projectDirectory.file(storeFileName).asFile
        val keyAlias = keystoreProperties.getProperty("keyAlias", "")
        val keyPassword = keystoreProperties.getProperty("keyPassword", "")
        val storePassword = keystoreProperties.getProperty("storePassword", "")

        if (isReleaseTaskRequested) {
            if (!releaseStoreFile.exists()) {
                throw GradleException(
                    "Release signing required: keystore not found at ${releaseStoreFile.path} " +
                        "(storeFile=$storeFileName in android/key.properties).",
                )
            }
            if (keyAlias.isBlank() || keyPassword.isBlank() || storePassword.isBlank()) {
                throw GradleException(
                    "Release signing required: keyAlias/keyPassword/storePassword " +
                        "must be set in android/key.properties.",
                )
            }
        }

        signingConfigs {
            create("release") {
                this.keyAlias = keyAlias
                this.keyPassword = keyPassword
                // Explicit: storeFile is relative to this module (android/app/), not repo root.
                storeFile = releaseStoreFile
                this.storePassword = storePassword
            }
        }
    }

    buildTypes {
        release {
            // Always sign release when key.properties is present (required for Release tasks).
            if (keystorePropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

dependencies {
    // Required for desugaring support used by some plugins (e.g., flutter_local_notifications)
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // AdMob pulls work-runtime 2.7.x which crashes under AGP 9 R8 full mode.
    // Force a newer WorkManager with correct consumer keep rules (googleads#1444).
    implementation("androidx.work:work-runtime:2.11.2")
}

flutter {
    source = "../.."
}
