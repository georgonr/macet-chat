#!/bin/bash

# Takes the prebuilt Windows desktop libraries - the Haskell core, its JNI shim, OpenSSL and VLC -
# out of the official SimpleX desktop release of the same tag and puts them where the Compose build
# expects them. This fork does not build the Haskell core from source, see MACET.md.
#
# The layout produced here is the one `scripts/desktop/build-lib-windows.sh` produces upstream:
#
#   apps/multiplatform/common/src/commonMain/cpp/desktop/libs/windows-x86_64/
#     libapp-lib.dll libcrypto-3-x64.dll libsimplex.dll vlc/
#   apps/multiplatform/build/links/windows-x64 -> ../../common/.../libs/windows-x86_64
#
# Windows only - it uses msiexec to unpack the installer.

set -e

function readlink() {
  echo "$(cd "$(dirname "$1")"; pwd -P)"
}
root_dir="$(dirname "$(dirname "$(readlink "$0")")")"

tag=${1:-v6.5.6}
msi_url="https://github.com/simplex-chat/simplex-chat/releases/download/${tag}/simplex-desktop-windows-x86_64.msi"

libs_dir=$root_dir/apps/multiplatform/common/src/commonMain/cpp/desktop/libs/windows-x86_64
links_dir=$root_dir/apps/multiplatform/build/links
work_dir=$root_dir/dist-newstyle/macet-desktop-libs

rm -rf "$work_dir"
mkdir -p "$work_dir"

echo "Downloading $msi_url"
curl --tlsv1.2 -L -o "$work_dir/simplex-desktop.msi" "$msi_url"

# An administrative install unpacks the MSI without installing anything.
msi_path=$(cygpath -w "$work_dir/simplex-desktop.msi")
target_path=$(cygpath -w "$work_dir/extract")
"$WINDIR/System32/msiexec.exe" //a "$msi_path" //qn TARGETDIR="$target_path"

resources=$work_dir/extract/SimpleX/app/resources
for lib in libapp-lib.dll libcrypto-3-x64.dll libsimplex.dll; do
  test -f "$resources/$lib" || { echo "$lib is missing from the release"; exit 1; }
done

rm -rf "$libs_dir"
mkdir -p "$libs_dir"
cp -p "$resources"/libapp-lib.dll "$resources"/libcrypto-3-x64.dll "$resources"/libsimplex.dll "$libs_dir/"
cp -rp "$resources/vlc" "$libs_dir/vlc"

# Compose reads the bundled resources from build/links/<os>-<compose arch>. A junction is used
# instead of a symlink because symlinks need developer mode or admin rights on Windows.
mkdir -p "$links_dir"
rm -rf "$links_dir/windows-x64"
cmd //c mklink //J "$(cygpath -w "$links_dir/windows-x64")" "$(cygpath -w "$libs_dir")" > /dev/null

rm -rf "$work_dir/extract"
echo "Windows desktop libraries of $tag are in $libs_dir"
