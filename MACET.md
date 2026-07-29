# Macet

Macet is an Android fork of [SimpleX Chat](https://github.com/simplex-chat/simplex-chat),
branched from the upstream release tag **v6.5.6**. It is the same messenger, branded as Macet
and pointed at the Macet servers.

Licensed under AGPL v3, like upstream. The `LICENSE` file and all licence headers are unchanged.

## What differs from upstream

| | upstream | Macet |
|---|---|---|
| applicationId | `chat.simplex.app` | `eu.macet.chat` |
| app name | SimpleX | Macet |
| launcher icon | SimpleX bitmaps | adaptive vector, `#0F172A` background, white "M" |
| operators | SimpleX Chat, Flux | Macet only |
| SMP server | `smp*.simplex.im`, `smp*.simplexonflux.com` | `cht.macet.eu:5223` |
| XFTP server | `xftp*.simplex.im`, `xftp*.simplexonflux.com` | `cht.macet.eu:5443` |
| WebRTC ICE | `stun/turn.simplex.im` | `turn:cht.macet.eu:3478` |

The Kotlin package name stays `chat.simplex.app` — it is the source package, not the app id.

### How the server configuration is enforced

The preset operators and their preset SMP/XFTP servers are compiled into the Haskell core
(`src/Simplex/Chat/Operators/Presets.hs`) and seeded into the chat database when it is created.
This fork uses the core as a **prebuilt binary**, and the core does not allow those rows to be
removed: `setUserServers'` in `src/Simplex/Chat/Store/Profiles.hs` only deletes servers with
`preset = 0`, and `updateServerOperator` only writes `enabled` and the operator roles.

So the configuration is enforced over the chat API instead, in
`apps/multiplatform/common/src/commonMain/kotlin/chat/simplex/common/model/MacetServers.kt`:

* every preset operator is disabled, which removes all of its servers from the configuration
  handed to the agent (`useServers` only collects servers of enabled operators);
* every preset server is disabled as well;
* the operator-less server group — the group used for new connections — is set to exactly the
  Macet SMP and XFTP server, enabled.

This runs on every chat start for every profile, and again right after a profile is created while
the chat is already running. It has to run *after* `apiStartChat` — the core answers both server
commands with `chatNotStarted` before that, which on a fresh install used to leave the preset
operators enabled and visible.

The onboarding operator picker and the preset-operator rows in *Network & servers* are removed,
so the disabled upstream operators are neither shown nor re-enableable. Both platforms share this
code; it lives in `commonMain` and the desktop app uses it through the same `ChatController`.

## Building

### Android

Requires JDK 17+, the Android SDK with NDK `23.1.7779620` and cmake `3.22.1`.

1. **Core libraries.** The Haskell core is *not* built from source. Take `libsimplex.so` and
   `libsupport.so` for both ABIs from the official upstream release of the same tag and place
   them where the CMake build expects them:

   ```
   apps/multiplatform/common/src/commonMain/cpp/android/libs/arm64-v8a/{libsimplex,libsupport}.so
   apps/multiplatform/common/src/commonMain/cpp/android/libs/armeabi-v7a/{libsimplex,libsupport}.so
   ```

   They can be extracted from `simplex-aarch64.apk` and `simplex-armv7a.apk` of the
   [v6.5.6 release](https://github.com/simplex-chat/simplex-chat/releases/tag/v6.5.6)
   (`lib/<abi>/` inside the APK), or downloaded with `scripts/android/download-libs.sh`.

2. **Signing.** Create `apps/multiplatform/keystore.properties` (git-ignored):

   ```properties
   storeFile=../../macet-release.keystore
   storePassword=...
   keyAlias=macet
   keyPassword=...
   ```

   Without this file the project still configures, and the release build is left unsigned.

3. **Build.**

   ```
   cd apps/multiplatform
   ./gradlew :android:assembleRelease     # APKs for the download page
   ./gradlew :android:bundleRelease       # AAB for Google Play
   ```

   Output: `apps/multiplatform/android/build/outputs/apk/release/`, split per ABI, and
   `.../bundle/release/android-release.aab`.

   **Run them as two separate invocations.** `android/build.gradle.kts` decides between ABI
   splits and a single bundle by looking for `bundle` in `gradle.startParameter.taskNames`, so
   asking for both tasks at once makes `isBundle` true for the whole build and `assembleRelease`
   then emits one universal APK instead of the per-ABI pair.

   The APKs are large — around 230 MB — because `compression.level` defaults to `0`, which stores
   the native libraries uncompressed so they can be mapped instead of extracted. That is the APK
   size, not the install size, and it does not apply to what Play serves: the same build delivered
   as an AAB downloads at roughly 62 MiB on arm64.

### Windows desktop

Requires JDK 17+ (JDK 21 is what the releases are built with) and the Android SDK, because the
`common` module is also an Android library. Neither the Haskell core nor its JNI shim is built
from source, so no MinGW, cmake or GHC is needed.

1. **Native libraries.** `libsimplex.dll` (the Haskell core), `libapp-lib.dll` (the JNI shim),
   `libcrypto-3-x64.dll` (OpenSSL) and the VLC libraries used for video playback are taken from
   `simplex-desktop-windows-x86_64.msi` of the upstream release of the same tag:

   ```
   scripts/macet/download-desktop-libs-windows.sh v6.5.6
   ```

   It unpacks the installer with `msiexec /a` and produces the layout that
   `scripts/desktop/build-lib-windows.sh` produces upstream:

   ```
   apps/multiplatform/common/src/commonMain/cpp/desktop/libs/windows-x86_64/
     libapp-lib.dll  libcrypto-3-x64.dll  libsimplex.dll  vlc/
   apps/multiplatform/build/links/windows-x64   (junction to the directory above)
   ```

   `build/links/<os>-<arch>` is what Compose bundles as the application resources, and
   `windowsLoadRequiredLibs` in `desktop/src/jvmMain/.../Main.kt` loads the DLLs from there.

2. **Build.**

   ```
   cd apps/multiplatform
   ./gradlew :desktop:packageDistributionForCurrentOS
   ```

   Output: `apps/multiplatform/release/main/msi/Macet Secure Chat-<version>.msi`.

   `desktop/build.gradle.kts` skips the CMake build of the JNI shim when `libapp-lib` for the host
   platform is already present, which is why a C toolchain is not needed. Pass `-PbuildNativeLibs`
   to build it from source anyway.
