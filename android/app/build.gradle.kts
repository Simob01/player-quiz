import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val admobApplicationId =
    (project.findProperty("ADMOB_APP_ID") as String?)
        ?.takeIf { it.isNotBlank() } ?: "ca-app-pub-4881887086524304~1131831419"
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

fun requiredKeystoreProperty(name: String): String =
    keystoreProperties.getProperty(name)?.takeIf { it.isNotBlank() }
        ?: throw GradleException("Missing '$name' in android/key.properties")

android {
    namespace = "com.noorstudy.gpatracker"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.noorstudy.gpatracker"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["admobApplicationId"] = admobApplicationId
    }

    signingConfigs {
        create("release") {
            if (!keystorePropertiesFile.exists()) {
                throw GradleException("Missing android/key.properties for release signing")
            }

            val releaseStoreFile = file(requiredKeystoreProperty("storeFile"))
            if (!releaseStoreFile.exists()) {
                throw GradleException("Release keystore not found at ${releaseStoreFile.path}")
            }

            storeFile = releaseStoreFile
            storePassword = requiredKeystoreProperty("storePassword")
            keyAlias = requiredKeystoreProperty("keyAlias")
            keyPassword = requiredKeystoreProperty("keyPassword")
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
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
    // Google Mobile Ads pulls WorkManager 2.7.0 transitively, which crashes
    // during AndroidX Startup on newer Android release builds before Flutter runs.
    implementation("androidx.work:work-runtime:2.10.0")
}
