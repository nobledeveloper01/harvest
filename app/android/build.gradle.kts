allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

/*
  One NDK for every module, and it is the one on the machine.

  Pinning `ndkVersion` in `app/build.gradle.kts` is not enough: a plugin module
  can set its own, and `jni` — which arrives transitively — sets
  `ndkVersion flutter.ndkVersion`. That property tracks whatever the installed
  Flutter pins, so a build silently starts downloading about a gigabyte of NDK
  before it compiles a line, on whatever connection happens to be there.

  Nothing in this app or its plugins has native code that needs a newer
  toolchain — `sqlite3_flutter_libs` ships prebuilt `.so` files — so the version
  is a reproducibility choice. This is where it is made, once, for everybody.

  **It is not sufficient on its own.** The Flutter tool resolves and installs
  the NDK before these blocks are evaluated, so a machine without the pinned
  version still downloads one — it just downloads whatever Flutter pins rather
  than what this file says. What the pin buys is a build that uses one known
  toolchain once the version is present, and a place for the next person to see
  that the choice was made rather than inherited.

  Raise it deliberately, and only after downloading it deliberately.
*/
val pinnedNdk = "27.1.12297006"

/*
  A plugin brings its own `compileSdk`, and there is no overriding it from here.

  `flutter_secure_storage` 9.2.4 asks for 34, and 11.0.0 asks for 37. Gradle
  **downloads** whichever it is told, mid-build, without asking — 152 MB of
  Android SDK Platform 37 arrived that way while this dependency was being
  evaluated, and then failed to be usable, because it installs as `android-37.0`
  and Gradle looks for `android-37`.

  This block used to try to raise them all to the app's own. It cannot:
  `plugins.withId` fires before the module's `android { compileSdk 34 }` and is
  overwritten by it, and `afterEvaluate` is refused outright — *it is too late to
  set compileSdk, it has already been read to configure this project*. AGP reads
  the value during the module's evaluation and there is no window between.

  So the defence is not a pin, it is knowing before you add: a plugin's
  `compileSdk` is one line in its `android/build.gradle`, readable from
  `~/.pub-cache` without building anything. Adding a Flutter plugin can cost an
  Android SDK platform, and that belongs in the decision rather than in the
  build log.
*/

subprojects {
    plugins.withId("com.android.library") {
        extensions.configure<com.android.build.gradle.LibraryExtension>("android") {
            ndkVersion = pinnedNdk
        }
    }
    plugins.withId("com.android.application") {
        extensions.configure<com.android.build.gradle.AppExtension>("android") {
            ndkVersion = pinnedNdk
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
