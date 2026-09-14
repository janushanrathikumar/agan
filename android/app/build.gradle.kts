import java.util.Properties
import java.io.FileInputStream

// 1. Load the key.properties file
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

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
    namespace = "ch.restaurantkleefeld.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "ch.restaurantkleefeld.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // One app per station, so both can be installed on the same tablet.
    // Each flavor pairs with its own Dart entrypoint:
    //   flutter build apk --flavor kitchen -t lib/main_kitchen.dart
    //   flutter build apk --flavor bar     -t lib/main_bar.dart
    flavorDimensions += "station"
    productFlavors {
        create("kitchen") {
            dimension = "station"
            applicationIdSuffix = ".kitchen"
            resValue("string", "app_name", "Kleefeld Kitchen")
        }
        create("bar") {
            dimension = "station"
            applicationIdSuffix = ".bar"
            resValue("string", "app_name", "Kleefeld Bar")
        }
    }

    // 2. Configure the Release Signing configuration.
    // Only declared when key.properties exists — otherwise reading the missing
    // keys here would fail every Gradle task, debug builds included.
    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = keystoreProperties["storeFile"]?.let { file(it) }
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // 3. Link the release build type to your new signing config, falling
            // back to the debug key so a release build still runs before a
            // keystore exists.
            signingConfig = signingConfigs.findByName("release")
                ?: signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
