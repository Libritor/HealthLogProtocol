import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.muse_headband_app"
    compileSdk = flutter.compileSdkVersion
    // ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlin {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.healthlog"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Load signing config from key.properties (gitignored) if it exists.
    // For first-time setup, copy key.properties.example to key.properties
    val keyPropertiesFile = rootProject.file("key.properties")
    val keyProperties = Properties()
    if (keyPropertiesFile.exists()) {
        keyProperties.load(FileInputStream(keyPropertiesFile))
    }

    signingConfigs {
        create("release") {
            if (keyPropertiesFile.exists()) {
                storeFile = file(keyProperties.getProperty("storeFile") ?: "upload-keystore.jks")
                storePassword = keyProperties.getProperty("storePassword") ?: ""
                keyAlias = keyProperties.getProperty("keyAlias") ?: "upload"
                keyPassword = keyProperties.getProperty("keyPassword") ?: ""
            }
        }
    }

    buildTypes {
        release {
            if (keyPropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            } else {
                // Dev builds use debug signing
                signingConfig = signingConfigs.getByName("debug")
            }
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // LibMuse SDK for connecting to Muse headbands
    implementation(fileTree(mapOf("dir" to "libs", "include" to listOf("*.jar", "*.aar"))))
}
