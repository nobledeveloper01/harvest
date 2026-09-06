plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "ng.harvest.harvest"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17

        // Required by `flutter_local_notifications`, which uses `java.time` to
        // schedule an alert for a moment in the future. The design floor is a
        // ₦40,000 handset, so `minSdk` is low enough that `java.time` is not in
        // the platform — desugaring back-ports it into the APK.
        //
        // Without this the Android build does not merely warn, it **fails**:
        // `checkDebugAarMetadata` refuses the dependency outright. Which means
        // the spoilage alerts — the product's whole wedge — could not be built
        // for the platform the farmer persona actually uses. Found by the first
        // Android compile in the project's history (R2), after the feature had
        // been shipping green on iOS for two phases.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "ng.harvest.harvest"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
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
    // The back-port itself. Pinned, because a build that silently changes what
    // it desugars is a build whose behaviour on a 2 GB handset changes without
    // anybody choosing it.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
