plugins {
    id("com.android.application")
    id("com.google.gms.google-services") // For Firebase
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.smart_wearable_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11 // Explicitly set to Java 11
        targetCompatibility = JavaVersion.VERSION_11 // Explicitly set to Java 11
        isCoreLibraryDesugaringEnabled = true // For flutter_local_notifications
    }

    kotlinOptions {
        jvmTarget = "11" // Use string "11" for consistency with Java 11
    }

    defaultConfig {
        applicationId = "com.example.smart_wearable_app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4") // Desugaring library
}

flutter {
    source = "../.."
}