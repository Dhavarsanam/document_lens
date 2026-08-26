plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.document_lens"
    compileSdk = 36  // 👈 explicit 36 — androidx libs (browser, activity, core-ktx) require this

    // Updated to the version requested by the "jni" plugin dependency
    // (they are backward compatible, so this covers the NDK 27 requesters too).
    ndkVersion = "28.2.13676358"

    compileOptions {
        // flutter_local_notifications 17.x REQUIRES core library desugaring.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.example.document_lens"
        // ML Kit + flutter_local_notifications are comfortable at 21+.
        minSdk = maxOf(flutter.minSdkVersion, 23)
        targetSdk = 36  // 👈 keep in sync with compileSdk
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // ML Kit text recognition ships native libs; keep all ABIs.
        multiDexEnabled = true
    }

    buildTypes {
        release {
            // Debug signing so `flutter build apk --release` works out of the
            // box. Replace with a real keystore before publishing to Play.
            signingConfig = signingConfigs.getByName("debug")

            // Keep R8/shrinking OFF for now — avoids stripping ML Kit /
            // notification classes. Turn on later with proper proguard rules.
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Required by flutter_local_notifications 17.x for release builds.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    // ✅ google_mlkit_text_recognition only bundles the Latin (English)
    // recognizer by default. The other scripts are SEPARATE native
    // libraries that must be added explicitly, or selecting that
    // language crashes with NoClassDefFoundError at runtime.
    implementation("com.google.mlkit:text-recognition-chinese:16.0.1")
    implementation("com.google.mlkit:text-recognition-devanagari:16.0.1")
    implementation("com.google.mlkit:text-recognition-japanese:16.0.1")
    implementation("com.google.mlkit:text-recognition-korean:16.0.1")
}