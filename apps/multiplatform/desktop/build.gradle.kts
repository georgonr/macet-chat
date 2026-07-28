import org.gradle.internal.extensions.stdlib.toDefaultLowerCase
import org.jetbrains.compose.desktop.application.dsl.TargetFormat

plugins {
  kotlin("multiplatform")
  id("org.jetbrains.compose")
  id("org.jetbrains.kotlin.plugin.compose")
  id("io.github.tomtzook.gradle-cmake") version "1.2.2"
}

group = "chat.simplex"
version = extra["desktop.version_name"] as String


kotlin {
  jvm()
  sourceSets {
    val jvmMain by getting {
      dependencies {
        implementation(project(":common"))
        implementation(compose.desktop.currentOs)
      }
    }
    val jvmTest by getting
  }
}

// https://github.com/JetBrains/compose-multiplatform/tree/master/tutorials/Native_distributions_and_local_execution
compose {
  desktop {
    application {
      // For debugging via VisualVM
      val debugJava = false
      if (debugJava) {
        jvmArgs += listOf(
          "-Dcom.sun.management.jmxremote.port=8080",
          "-Dcom.sun.management.jmxremote.ssl=false",
          "-Dcom.sun.management.jmxremote.authenticate=false"
        )
      }
      mainClass = "chat.simplex.desktop.MainKt"
      nativeDistributions {
        copyright = "(c) 2020-2026 SimpleX Chat"
        // For debugging via VisualVM
        if (debugJava) {
          modules("jdk.zipfs", "jdk.unsupported", "jdk.management.agent")
        } else {
          // 'jdk.unsupported' is for vlcj
          modules("jdk.zipfs", "jdk.unsupported")
        }
        //includeAllModules = true
        outputBaseDir.set(project.file("../release"))
        appResourcesRootDir.set(project.file("../build/links"))
        targetFormats(
          TargetFormat.Deb, TargetFormat.Dmg, TargetFormat.Msi, TargetFormat.Exe
          //, TargetFormat.AppImage // Gradle doesn't sync on Mac with it
        )
        linux {
          iconFile.set(project.file("src/jvmMain/resources/distribute/simplex.png"))
          appCategory = "Messenger"
        }
        windows {
          packageName = "SimpleX"
          iconFile.set(project.file("src/jvmMain/resources/distribute/simplex.ico"))
          console = false
          perUserInstall = false
          dirChooser = true
          shortcut = true
          upgradeUuid = "CC9EFBC8-AFFF-40D8-BB69-FCD7CE99EFB9"
        }
        macOS {
          packageName = "SimpleX"
          iconFile.set(project.file("src/jvmMain/resources/distribute/simplex.icns"))
          appCategory = "public.app-category.social-networking"
          bundleID = "chat.simplex.app"
          infoPlist {
            extraKeysRawXml = """
              <key>NSMicrophoneUsageDescription</key>
              <string>SimpleX needs microphone access to record voice messages</string>
            """
          }
          val identity = rootProject.extra["desktop.mac.signing.identity"] as String?
          val keychain = rootProject.extra["desktop.mac.signing.keychain"] as String?
          val appleId = rootProject.extra["desktop.mac.notarization.apple_id"] as String?
          val password = rootProject.extra["desktop.mac.notarization.password"] as String?
          val teamId = rootProject.extra["desktop.mac.notarization.team_id"] as String?
          if (identity != null && keychain != null && appleId != null && password != null) {
            signing {
              sign.set(true)
              this.identity.set(identity)
              this.keychain.set(keychain)
            }
            notarization {
              this.appleID.set(appleId)
              this.password.set(password)
              this.teamID.set(teamId)
            }
          }
        }
        val os = System.getProperty("os.name", "generic").toDefaultLowerCase()
        if (os.contains("mac") || os.contains("win")) {
          packageName = "SimpleX"
        } else {
          packageName = "simplex"
        }
        // Packaging requires to have version like MAJOR.MINOR.PATCH
        var adjustedVersion = rootProject.extra["desktop.version_name"] as String
        adjustedVersion = adjustedVersion.replace(Regex("[^0-9.]"), "")
        val split = adjustedVersion.split(".")
        adjustedVersion = split[0] + "." + (split.getOrNull(1) ?: "0") + "." + (split.getOrNull(2) ?: "0")
        version = adjustedVersion
      }
    }
  }
}

val cppPath = "../common/src/commonMain/cpp"
cmake {
  // Run this command to make build for all targets:
  // ./gradlew common:cmakeBuild -PcrossCompile
  if (project.hasProperty("crossCompile")) {
    machines.customMachines.register("linux-amd64") {
      toolchainFile.set(project.file("$cppPath/toolchains/x86_64-linux-gnu-gcc.cmake"))
    }
    /*machines.customMachines.register("linux-aarch64") {
      toolchainFile.set(project.file("$cppPath/toolchains/aarch64-linux-gnu-gcc.cmake"))
    }*/
    /*machines.customMachines.register("win-amd64") {
      toolchainFile.set(project.file("$cppPath/toolchains/x86_64-windows-mingw32-gcc.cmake"))
    }*/
    if (machines.host.name == "mac-amd64") {
      machines.customMachines.register("mac-amd64") {
        toolchainFile.set(project.file("$cppPath/toolchains/x86_64-mac-apple-darwin-gcc.cmake"))
      }
    }
    if (machines.host.name == "mac-aarch64") {
      machines.customMachines.register("mac-aarch64") {
        toolchainFile.set(project.file("$cppPath/toolchains/aarch64-mac-apple-darwin-gcc.cmake"))
      }
    }
  }
  val compileMachineTargets = arrayListOf<com.github.tomtzook.gcmake.targets.TargetMachine>(machines.host)
  compileMachineTargets.addAll(machines.customMachines)
  targets {
    val main by creating {
      cmakeLists.set(file("$cppPath/desktop/CMakeLists.txt"))
      targetMachines.addAll(compileMachineTargets.toSet())
      //if (machines.host.name.contains("win")) {
      //  cmakeArgs.add("-G MinGW Makefiles")
      //}
    }
  }
}

// This fork uses the Haskell core and its JNI shim as prebuilt binaries - see MACET.md. When
// libapp-lib is already in place for the host platform there is nothing for CMake to build, and
// requiring a local CMake/MinGW toolchain would only break the build. Pass -PbuildNativeLibs to
// build the shim from source anyway.
val hostLibDir = run {
  val os = System.getProperty("os.name", "generic").toDefaultLowerCase()
  val name = if (os.contains("win")) "windows" else if (os.contains("mac")) "mac" else "linux"
  val arch = System.getProperty("os.arch", "").toDefaultLowerCase()
  val cpu = if (arch.contains("aarch64") || arch.contains("arm64")) "aarch64" else "x86_64"
  val ext = if (name == "windows") "dll" else if (name == "mac") "dylib" else "so"
  project.file("$cppPath/desktop/libs/$name-$cpu/libapp-lib.$ext")
}
val buildNativeLibs = project.hasProperty("buildNativeLibs") || !hostLibDir.exists()

if (buildNativeLibs) {
  tasks.named("clean") {
    dependsOn("cmakeClean")
  }
  tasks.named("compileKotlinJvm") {
    dependsOn("cmakeBuildAndCopy")
  }
} else {
  logger.lifecycle("Using prebuilt native libraries from ${hostLibDir.parentFile}; skipping CMake build")
}
afterEvaluate {
  tasks.create("cmakeBuildAndCopy") {
    dependsOn("cmakeBuild")
    doLast {
      copy {
        from("${project(":desktop").buildDir}/cmake/main/linux-amd64")
        into("$cppPath/desktop/libs/linux-x86_64")
        include("*.so*")
        eachFile {
          path = name
        }
        includeEmptyDirs = false
        duplicatesStrategy = DuplicatesStrategy.INCLUDE
      }
      copy {
        from("${project(":desktop").buildDir}/cmake/main/linux-aarch64")
        into("$cppPath/desktop/libs/linux-aarch64")
        include("*.so*")
        eachFile {
          path = name
        }
        includeEmptyDirs = false
        duplicatesStrategy = DuplicatesStrategy.INCLUDE
      }
      copy {
        from("${project(":desktop").buildDir}/cmake/main/windows-amd64")
        into("$cppPath/desktop/libs/windows-x86_64")
        include("*.dll")
        eachFile {
          path = name
        }
        includeEmptyDirs = false
        duplicatesStrategy = DuplicatesStrategy.INCLUDE
      }
	  copy {
        from("${project(":desktop").buildDir}/cmake/main/windows-amd64")
        into("../build/links/windows-x64")
        include("*.dll")
        eachFile {
          path = name
        }
        includeEmptyDirs = false
        duplicatesStrategy = DuplicatesStrategy.INCLUDE
      }
      copy {
        from("${project(":desktop").buildDir}/cmake/main/mac-x86_64")
        into("$cppPath/desktop/libs/mac-x86_64")
        include("*.dylib")
        eachFile {
          path = name
        }
        includeEmptyDirs = false
        duplicatesStrategy = DuplicatesStrategy.INCLUDE
      }
      copy {
        from("${project(":desktop").buildDir}/cmake/main/mac-aarch64")
        into("$cppPath/desktop/libs/mac-aarch64")
        include("*.dylib")
        eachFile {
          path = name
        }
        includeEmptyDirs = false
        duplicatesStrategy = DuplicatesStrategy.INCLUDE
      }
    }
  }
}
