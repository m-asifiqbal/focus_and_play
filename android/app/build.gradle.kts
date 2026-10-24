import java.util.Base64
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing: android/key.properties (never committed). Without it the
// release build falls back to the debug key (fine for testing, not for Play).
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}

// --dart-define / --dart-define-from-file values reach Gradle as base64 "KEY=value"
// pairs. Read so config/admob.json can also set the AdMob *app* id in the manifest.
val dartDefines: Map<String, String> = (project.findProperty("dart-defines") as String?)
    ?.split(",")
    ?.mapNotNull { entry ->
        val pair = String(Base64.getDecoder().decode(entry), Charsets.UTF_8).split("=", limit = 2)
        if (pair.size == 2) pair[0] to pair[1] else null
    }
    ?.toMap()
    ?: emptyMap()

android {
    namespace = "com.iqballabs.focus_and_play"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications uses java.time on older Android versions.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Permanent once published on Google Play — change it before the first upload if needed.
        applicationId = "com.iqballabs.focus_and_play"
        // google_mobile_ads needs API 23+.
        minSdk = maxOf(23, flutter.minSdkVersion)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // AdMob app id for AndroidManifest.xml; defaults to Google's TEST app id.
        manifestPlaceholders["admobAppId"] =
            dartDefines["ADMOB_APP_ID_ANDROID"]?.takeIf { it.isNotBlank() }
                ?: "ca-app-pub-3940256099942544~3347511713"
    }

    signingConfigs {
        if (keystoreProperties.containsKey("storeFile")) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Falls back to debug keys until android/key.properties exists,
            // so `flutter run --release` still works on a dev machine.
            signingConfig = signingConfigs.findByName("release")
                ?: signingConfigs.getByName("debug")
            // Keep rules for classes created by reflection; without them the
            // release app crashed at launch (see the file's header).
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
