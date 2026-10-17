import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// Google Play upload key. android/key.properties (git-ignored) holds the
// keystore path and passwords. Without that file, release builds fall back
// to the debug key so anyone can still build a release APK locally — but
// only a build signed with the upload key can go to Play.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.amana.mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.amana.mobile"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Drop unused locale resources from bundled libraries (Firebase, Play
        // Services, Mapbox). We only ship en/ar/fr; everything else is dead
        // weight. resourceConfigurations is the AGP <8.5 spelling of
        // androidResources.localeFilters.
        resourceConfigurations += listOf("en", "ar", "fr")
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        debug {
            // Debug keeps all ABIs so the app runs on x86_64 emulators.
        }
        release {
            // Ship only 64-bit ARM. Real Android phones since 2019 are arm64-v8a;
            // x86_64 is emulator-only, armeabi-v7a is legacy 32-bit. Dropping both
            // removes ~2/3 of the native-lib payload (Mapbox, flutter_sound,
            // Firebase, etc. each ship one .so per ABI), shrinking the default
            // universal APK from ~150 MB to ~50 MB.
            ndk {
                abiFilters += listOf("arm64-v8a")
            }
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            // R8 minification is OFF: with Mapbox + Firebase + supabase_flutter
            // it requires hand-tuned -keep rules and crashed the Gradle daemon
            // on a 16 GB machine. The size win was already taken by
            // arm64-v8a-only `abiFilters` above (~2/3 APK reduction).
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
