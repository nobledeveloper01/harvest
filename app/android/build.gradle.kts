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
