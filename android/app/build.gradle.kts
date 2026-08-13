import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseSigningProperties = Properties()
val releaseSigningPropertiesFile = rootProject.file("key.properties")
if (releaseSigningPropertiesFile.exists()) {
    FileInputStream(releaseSigningPropertiesFile).use(releaseSigningProperties::load)
}

fun releaseCredential(propertyName: String, environmentVariableName: String): String? =
    releaseSigningProperties.getProperty(propertyName)?.takeIf { it.isNotBlank() }
        ?: System.getenv(environmentVariableName)?.takeIf { it.isNotBlank() }

val releaseStoreFilePath = releaseCredential("storeFile", "ANDROID_RELEASE_STORE_FILE")
val releaseStorePassword = releaseCredential("storePassword", "ANDROID_RELEASE_STORE_PASSWORD")
val releaseKeyAlias = releaseCredential("keyAlias", "ANDROID_RELEASE_KEY_ALIAS")
val releaseKeyPassword = releaseCredential("keyPassword", "ANDROID_RELEASE_KEY_PASSWORD")
val hasReleaseSigningCredentials = listOf(
    releaseStoreFilePath,
    releaseStorePassword,
    releaseKeyAlias,
    releaseKeyPassword,
).all { credential -> credential != null }
val releaseBuildRequested = gradle.startParameter.taskNames.any { taskName ->
    taskName.contains("release", ignoreCase = true)
}

if (releaseBuildRequested && !hasReleaseSigningCredentials) {
    throw GradleException(
        "Release signing credentials are missing. Configure android/key.properties " +
            "or ANDROID_RELEASE_STORE_FILE, ANDROID_RELEASE_STORE_PASSWORD, " +
            "ANDROID_RELEASE_KEY_ALIAS, and ANDROID_RELEASE_KEY_PASSWORD.",
    )
}

android {
    namespace = "com.mightypresence.budget_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.mightypresence.budget_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigningCredentials) {
            create("release") {
                storeFile = rootProject.file(releaseStoreFilePath!!)
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("release")
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
