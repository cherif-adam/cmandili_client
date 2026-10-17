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
    // Pinned rather than flutter.compileSdkVersion: Google Play requires
    // target API 36 and Flutter 3.32 still defaults to 35.
    compileSdk = 36
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
        targetSdk = 36
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
            // ARM only: arm64-v8a for current phones, armeabi-v7a so older 32-bit
            // phones can still install. x86_64 is emulator-only and stays out.
            // Play splits the App Bundle per ABI, so each phone downloads only
            // its own native libraries.
            ndk {
                abiFilters += listOf("arm64-v8a", "armeabi-v7a")
            }
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            // R8 minification is OFF: with Mapbox + Firebase + supabase_flutter
            // it requires hand-tuned -keep rules and crashed the Gradle daemon
            // on a 16 GB machine. The size win comes from the ARM-only
            // `abiFilters` above instead. No R8 means no mapping.txt.
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
