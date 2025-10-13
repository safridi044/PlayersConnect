plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")       // Kotlin plugin
    id("dev.flutter.flutter-gradle-plugin")  // Flutter plugin
    id("com.google.gms.google-services")     // Firebase plugin
}

android {
    namespace = "com.example.first_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    defaultConfig {
        applicationId = "com.example.first_app" // Must match Firebase package name
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Replace with a proper signing config for release builds
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    // ✅ Combine into one clean compileOptions block
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        // Fix for flutter_local_notifications: enable desugaring
        isCoreLibraryDesugaringEnabled = true
    }

    // ✅ Set JVM target consistently to Java 11
    kotlinOptions {
        jvmTarget = "11"
    }
}

flutter {
    source = "../.."
}

dependencies {
    // ✅ Required to fix "core library desugaring" error
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    // Other dependencies added by Flutter/Firebase will auto-merge here
}