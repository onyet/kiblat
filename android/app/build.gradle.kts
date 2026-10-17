plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties

// Read .env file from project root
fun loadEnvFile(): Map<String, String> {
    val envFile = file("../../.env")
    val envMap = mutableMapOf<String, String>()
    if (envFile.exists()) {
        envFile.readLines().forEach { line ->
            if (line.isNotBlank() && !line.startsWith("#") && line.contains("=")) {
                val (key, value) = line.split("=", limit = 2)
                envMap[key.trim()] = value.trim()
            }
        }
    }
    return envMap
}

val envVars = loadEnvFile()
val googleApiKey = envVars["GOOGLE_API_KEY"] ?: ""

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

        // Manifest placeholders for API keys from .env
        // Restrict this key in Google Cloud Console to Android apps:
        // package id.onyet.app.kiblat + your upload/App Signing SHA-1.
        manifestPlaceholders["googleApiKey"] = googleApiKey
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
}

flutter {
    source = "../.."
}
