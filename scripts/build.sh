#!/usr/bin/env bash
# Builds an LGPL-only FFmpeg (static libs) + codec libs for one Apple SDK, then links
# everything into ONE dynamic framework (FFmpegLGPL.framework) so the app can relink/replace it.
# Usage: scripts/build.sh iphoneos|iphonesimulator
set -euo pipefail

SDKNAME="${1:?usage: build.sh iphoneos|iphonesimulator}"
MINVER="${MINVER:-17.0}"
JOBS="$(sysctl -n hw.ncpu)"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/build/src"
WORK="$ROOT/build/$SDKNAME"
PREFIX="$WORK/prefix"
OUT="$ROOT/build/out/$SDKNAME"
mkdir -p "$SRC" "$WORK" "$PREFIX/lib/pkgconfig" "$OUT"

# shellcheck disable=SC1091
source "$ROOT/scripts/versions.env"

SDK="$(xcrun --sdk "$SDKNAME" --show-sdk-path)"
if [ "$SDKNAME" = iphoneos ]; then
  TARGET="arm64-apple-ios${MINVER}"
  CMAKE_SYSROOT=iphoneos
else
  TARGET="arm64-apple-ios${MINVER}-simulator"
  CMAKE_SYSROOT=iphonesimulator
fi
CC="$(xcrun --sdk "$SDKNAME" -f clang)"
CXX="$(xcrun --sdk "$SDKNAME" -f clang++)"
AR="$(xcrun --sdk "$SDKNAME" -f ar)"
RANLIB="$(xcrun --sdk "$SDKNAME" -f ranlib)"
STRIP="$(xcrun --sdk "$SDKNAME" -f strip)"
COMMON="-target $TARGET -isysroot $SDK -O2 -fPIC -g0"

export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig"
export PKG_CONFIG_LIBDIR="$PREFIX/lib/pkgconfig"

fetch() { # name url file
  local file="$SRC/$3"
  if [ ! -s "$file" ]; then
    for i in 1 2 3 4; do
      curl -fL --retry 3 -o "$file" "$2" && break || { echo "retry $i for $1"; sleep 5; }
    done
  fi
  [ -s "$file" ] || { echo "download failed: $1"; exit 1; }
}
unpack() { # file dir
  rm -rf "$WORK/$2"; mkdir -p "$WORK/$2"
  tar -xf "$SRC/$1" -C "$WORK/$2" --strip-components=1
  # old autotools scripts add a linker flag that Apple's current ld rejects
  if [ -f "$WORK/$2/configure" ]; then perl -pi -e 's/-force_cpusubtype_ALL//g' "$WORK/$2/configure"; fi
}
section() { echo; echo "=================== $* ==================="; }

# ---------- libogg ----------
section libogg
fetch libogg "https://downloads.xiph.org/releases/ogg/libogg-$LIBOGG_VERSION.tar.gz" "libogg-$LIBOGG_VERSION.tar.gz"
unpack "libogg-$LIBOGG_VERSION.tar.gz" libogg
( cd "$WORK/libogg" && CC="$CC" CFLAGS="$COMMON" LDFLAGS="-target $TARGET -isysroot $SDK" \
  ./configure --host=aarch64-apple-darwin --prefix="$PREFIX" --disable-shared --enable-static >/dev/null \
  && make -j"$JOBS" >/dev/null && make install >/dev/null )

# ---------- libvorbis ----------
section libvorbis
fetch libvorbis "https://downloads.xiph.org/releases/vorbis/libvorbis-$LIBVORBIS_VERSION.tar.gz" "libvorbis-$LIBVORBIS_VERSION.tar.gz"
unpack "libvorbis-$LIBVORBIS_VERSION.tar.gz" libvorbis
( cd "$WORK/libvorbis" && CC="$CC" CFLAGS="$COMMON" LDFLAGS="-target $TARGET -isysroot $SDK" \
  ./configure --host=aarch64-apple-darwin --prefix="$PREFIX" --disable-shared --enable-static --disable-oggtest --disable-docs --disable-examples >/dev/null \
  && make -j"$JOBS" >/dev/null && make install >/dev/null )

# ---------- libtheora ----------
section libtheora
fetch libtheora "https://downloads.xiph.org/releases/theora/libtheora-$LIBTHEORA_VERSION.tar.gz" "libtheora-$LIBTHEORA_VERSION.tar.gz"
unpack "libtheora-$LIBTHEORA_VERSION.tar.gz" libtheora
( cd "$WORK/libtheora" && CC="$CC" CFLAGS="$COMMON" LDFLAGS="-target $TARGET -isysroot $SDK"   ./configure --host=aarch64-apple-darwin --prefix="$PREFIX" --disable-shared --enable-static --disable-oggtest --disable-vorbistest     --disable-sdltest --disable-examples --disable-spec --disable-doc --disable-asm >/dev/null   && make -j"$JOBS" >/dev/null && make install >/dev/null )

# ---------- lame ----------
section libmp3lame
fetch lame "https://downloads.sourceforge.net/project/lame/lame/$LAME_VERSION/lame-$LAME_VERSION.tar.gz" "lame-$LAME_VERSION.tar.gz"
unpack "lame-$LAME_VERSION.tar.gz" lame
( cd "$WORK/lame" && CC="$CC" CFLAGS="$COMMON" LDFLAGS="-target $TARGET -isysroot $SDK" \
  ./configure --host=aarch64-apple-darwin --prefix="$PREFIX" --disable-shared --enable-static --disable-frontend --disable-decoder --disable-gtktest >/dev/null \
  && make -C libmp3lame CFLAGS="$COMMON -include stdlib.h -include string.h -include strings.h -include math.h -Wno-implicit-function-declaration" -j"$JOBS" >/dev/null && make -C libmp3lame install >/dev/null && make -C include install >/dev/null )

# ---------- opus (cmake) ----------
section libopus
fetch opus "https://downloads.xiph.org/releases/opus/opus-$OPUS_VERSION.tar.gz" "opus-$OPUS_VERSION.tar.gz"
unpack "opus-$OPUS_VERSION.tar.gz" opus
cmake -S "$WORK/opus" -B "$WORK/opus/b" -G Ninja -DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_SYSROOT="$CMAKE_SYSROOT" \
  -DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_OSX_DEPLOYMENT_TARGET="$MINVER" -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DBUILD_SHARED_LIBS=OFF -DCMAKE_POSITION_INDEPENDENT_CODE=ON -DOPUS_BUILD_PROGRAMS=OFF -DOPUS_BUILD_TESTING=OFF \
  -DOPUS_INSTALL_PKG_CONFIG_MODULE=ON -DOPUS_INSTALL_CMAKE_CONFIG_MODULE=OFF >/dev/null
cmake --build "$WORK/opus/b" -j "$JOBS" >/dev/null && cmake --install "$WORK/opus/b" >/dev/null

# ---------- libwebp (cmake) ----------
section libwebp
fetch libwebp "https://storage.googleapis.com/downloads.webmproject.org/releases/webp/libwebp-$LIBWEBP_VERSION.tar.gz" "libwebp-$LIBWEBP_VERSION.tar.gz"
unpack "libwebp-$LIBWEBP_VERSION.tar.gz" libwebp
cmake -S "$WORK/libwebp" -B "$WORK/libwebp/b" -G Ninja -DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_SYSROOT="$CMAKE_SYSROOT" \
  -DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_OSX_DEPLOYMENT_TARGET="$MINVER" -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DBUILD_SHARED_LIBS=OFF -DCMAKE_POSITION_INDEPENDENT_CODE=ON -DWEBP_BUILD_ANIM_UTILS=OFF -DWEBP_BUILD_CWEBP=OFF \
  -DWEBP_BUILD_DWEBP=OFF -DWEBP_BUILD_GIF2WEBP=OFF -DWEBP_BUILD_IMG2WEBP=OFF -DWEBP_BUILD_VWEBP=OFF -DWEBP_BUILD_WEBPINFO=OFF \
  -DWEBP_BUILD_WEBPMUX=OFF -DWEBP_BUILD_EXTRAS=OFF -DWEBP_BUILD_LIBWEBPMUX=ON >/dev/null
cmake --build "$WORK/libwebp/b" -j "$JOBS" >/dev/null && cmake --install "$WORK/libwebp/b" >/dev/null

# ---------- libvpx ----------
section libvpx
fetch libvpx "https://github.com/webmproject/libvpx/archive/refs/tags/v$LIBVPX_VERSION.tar.gz" "libvpx-$LIBVPX_VERSION.tar.gz"
unpack "libvpx-$LIBVPX_VERSION.tar.gz" libvpx
VPX_TARGET=arm64-darwin-gcc
# libvpx hard-codes its own -isysroot / -miphoneos-version-min flags (iOS 8, device SDK). Wrap the compiler so our
# target triple and SDK always win (this is what makes the simulator slice come out as a real simulator build).
cat > "$WORK/cc-wrap.sh" <<WRAP
#!/bin/bash
args=()
skip=0
for a in "\$@"; do
  if [ "\$skip" = 1 ]; then skip=0; continue; fi
  case "\$a" in
    -isysroot) skip=1 ;;
    -miphoneos-version-min=*|-mios-simulator-version-min=*|-mios-version-min=*|-arch) [ "\$a" = "-arch" ] && skip=1 ;;
    *) args+=("\$a") ;;
  esac
done
exec "$CC" -target $TARGET -isysroot "$SDK" "\${args[@]}"
WRAP
chmod +x "$WORK/cc-wrap.sh"
# libvpx's configure ignores $CC on Darwin and asks `xcrun --sdk iphoneos --find clang|as` instead, which always yields a
# device build. Shadow xcrun so those lookups return target-aware wrappers (needed for the simulator slice).
cat > "$WORK/as-wrap.sh" <<ASWRAP
#!/bin/bash
args=()
skip=0
for a in "\$@"; do
  if [ "\$skip" = 1 ]; then skip=0; continue; fi
  case "\$a" in
    -arch) skip=1 ;;
    *) args+=("\$a") ;;
  esac
done
exec "$CC" -target $TARGET -isysroot "$SDK" -c "\${args[@]}"
ASWRAP
chmod +x "$WORK/as-wrap.sh"
mkdir -p "$WORK/shim"
cat > "$WORK/shim/xcrun" <<XCRUN
#!/bin/bash
find=0; last=""
for a in "\$@"; do [ "\$a" = "--find" ] && find=1; last="\$a"; done
if [ \$find = 1 ]; then
  case "\$last" in
    clang|clang++) echo "$WORK/cc-wrap.sh"; exit 0 ;;
    as) echo "$WORK/as-wrap.sh"; exit 0 ;;
  esac
fi
exec /usr/bin/xcrun "\$@"
XCRUN
chmod +x "$WORK/shim/xcrun"
( cd "$WORK/libvpx" && export PATH="$WORK/shim:$PATH" && CC="$WORK/cc-wrap.sh" CXX="$WORK/cc-wrap.sh" AS="$WORK/cc-wrap.sh" LD="$WORK/cc-wrap.sh" AR="$AR" STRIP="$STRIP"   ./configure --target="$VPX_TARGET" --prefix="$PREFIX"   --disable-examples --disable-tools --disable-docs --disable-unit-tests --disable-install-bins --disable-install-srcs   --enable-vp8 --enable-vp9 --enable-pic --enable-static --disable-shared --enable-vp9-highbitdepth   && make -j"$JOBS" && make install )
# libvpx may install headers/libs without a pkg-config file for cross builds; make sure one exists
if [ ! -f "$PREFIX/lib/pkgconfig/vpx.pc" ]; then
cat > "$PREFIX/lib/pkgconfig/vpx.pc" <<EOF
prefix=$PREFIX
libdir=\${prefix}/lib
includedir=\${prefix}/include
Name: vpx
Description: WebM VP8/VP9 codec library
Version: $LIBVPX_VERSION
Libs: -L\${libdir} -lvpx -lm
Cflags: -I\${includedir}
EOF
fi

# ---------- dav1d (meson) ----------
section libdav1d
fetch dav1d "https://downloads.videolan.org/pub/videolan/dav1d/$DAV1D_VERSION/dav1d-$DAV1D_VERSION.tar.xz" "dav1d-$DAV1D_VERSION.tar.xz"
unpack "dav1d-$DAV1D_VERSION.tar.xz" dav1d
cat > "$WORK/dav1d-cross.txt" <<EOF
[binaries]
c = '$CC'
ar = '$AR'
strip = '$STRIP'
[built-in options]
c_args = ['-target', '$TARGET', '-isysroot', '$SDK']
c_link_args = ['-target', '$TARGET', '-isysroot', '$SDK']
[host_machine]
system = 'darwin'
subsystem = 'ios'
kernel = 'xnu'
cpu_family = 'aarch64'
cpu = 'aarch64'
endian = 'little'
EOF
( cd "$WORK/dav1d" && meson setup b --cross-file "$WORK/dav1d-cross.txt" --prefix "$PREFIX" --default-library=static --buildtype=release \
  -Denable_tools=false -Denable_tests=false -Denable_examples=false -Db_pie=true && ninja -C b && ninja -C b install )

# ---------- FFmpeg ----------
section ffmpeg
fetch ffmpeg "https://ffmpeg.org/releases/ffmpeg-$FFMPEG_VERSION.tar.xz" "ffmpeg-$FFMPEG_VERSION.tar.xz"
unpack "ffmpeg-$FFMPEG_VERSION.tar.xz" ffmpeg
(
  cd "$WORK/ffmpeg"
  ./configure \
    --prefix="$PREFIX/ffmpeg" \
    --enable-cross-compile --target-os=darwin --arch=arm64 \
    --cc="$CC" --cxx="$CXX" --ar="$AR" --ranlib="$RANLIB" --strip="$STRIP" \
    --sysroot="$SDK" \
    --extra-cflags="-target $TARGET -isysroot $SDK -I$PREFIX/include -fPIC -O2" \
    --extra-ldflags="-target $TARGET -isysroot $SDK -L$PREFIX/lib" \
    --pkg-config=pkg-config --pkg-config-flags="--static" \
    --disable-autodetect --disable-debug --disable-doc --disable-programs --disable-avdevice --disable-network \
    --disable-shared --enable-static --enable-pic --disable-symver \
    --disable-gpl --disable-nonfree --disable-version3 \
    --enable-zlib --enable-videotoolbox --enable-audiotoolbox \
    --enable-libvpx --enable-libopus --enable-libvorbis --enable-libtheora --enable-libmp3lame --enable-libwebp --enable-libdav1d \
    --logfile="$ROOT/ffconfig-$SDKNAME.log" \
    || { echo '=== configure failed: config.log tail ==='; echo "pwd=$(pwd)"; ls -la . | head -30; L="$ROOT/ffconfig-$SDKNAME.log"; ls -la "$L"; grep -n -B3 -A22 'vpx_codec_dec_init\|libvpx' "$L" | tail -n 120; ls -la "$PREFIX/lib" | head -40; nm -g "$PREFIX/lib/libvpx.a" 2>/dev/null | grep -E 'vpx_codec_dec_init_ver|vpx_codec_vp8_dx' | head; lipo -info "$PREFIX/lib/libvpx.a"; exit 1; }
  grep -E '^(CONFIG_GPL|CONFIG_NONFREE|CONFIG_VERSION3)=' ffbuild/config.mak || true
  make -j"$JOBS"
  make install
)

# ---------- link ONE dynamic framework ----------
section framework
FW="$OUT/FFmpegLGPL.framework"
rm -rf "$FW"; mkdir -p "$FW/Headers"
FFLIB="$PREFIX/ffmpeg/lib"
# libswscale and libavcodec both carry half2float.o; with -all_load that is a duplicate symbol. Keep avcodec's copy.
cp "$FFLIB/libswscale.a" "$WORK/libswscale_nohalf.a"
/usr/bin/ar d "$WORK/libswscale_nohalf.a" half2float.o
"$CC" -dynamiclib -target "$TARGET" -isysroot "$SDK" \
  -install_name "@rpath/FFmpegLGPL.framework/FFmpegLGPL" \
  -compatibility_version 1.0.0 -current_version 1.0.0 \
  -Wl,-all_load \
  "$FFLIB/libavformat.a" "$FFLIB/libavcodec.a" "$FFLIB/libavfilter.a" "$WORK/libswscale_nohalf.a" "$FFLIB/libswresample.a" "$FFLIB/libavutil.a" \
  "$PREFIX/lib/libvpx.a" "$PREFIX/lib/libopus.a" "$PREFIX/lib/libvorbisenc.a" "$PREFIX/lib/libvorbis.a" "$PREFIX/lib/libtheoraenc.a" "$PREFIX/lib/libtheoradec.a" "$PREFIX/lib/libogg.a" \
  "$PREFIX/lib/libmp3lame.a" "$PREFIX/lib/libwebp.a" "$PREFIX/lib/libwebpmux.a" "$PREFIX/lib/libsharpyuv.a" "$PREFIX/lib/libdav1d.a" \
  -framework CoreFoundation -framework CoreMedia -framework CoreVideo -framework VideoToolbox -framework AudioToolbox -framework Security \
  -lz -lm -lc++ \
  -o "$FW/FFmpegLGPL"
# headers (kept in their lib sub-folders so quoted includes work when used with -I <dir>)
for d in libavutil libavcodec libavformat libavfilter libswscale libswresample; do cp -R "$PREFIX/ffmpeg/include/$d" "$FW/Headers/"; done
cat > "$FW/Headers/FFmpegLGPL.h" <<'EOF'
// Umbrella header. Add the framework's Headers folder to HEADER_SEARCH_PATHS and #include "FFmpegLGPL.h".
#include "libavutil/avutil.h"
#include "libavutil/opt.h"
#include "libavutil/imgutils.h"
#include "libavutil/channel_layout.h"
#include "libavutil/samplefmt.h"
#include "libavutil/pixdesc.h"
#include "libavutil/display.h"
#include "libavcodec/avcodec.h"
#include "libavformat/avformat.h"
#include "libavfilter/avfilter.h"
#include "libavfilter/buffersrc.h"
#include "libavfilter/buffersink.h"
#include "libswscale/swscale.h"
#include "libswresample/swresample.h"
EOF
cat > "$FW/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleDevelopmentRegion</key><string>en</string>
<key>CFBundleExecutable</key><string>FFmpegLGPL</string>
<key>CFBundleIdentifier</key><string>com.ecomswift.FFmpegLGPL</string>
<key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
<key>CFBundleName</key><string>FFmpegLGPL</string>
<key>CFBundlePackageType</key><string>FMWK</string>
<key>CFBundleShortVersionString</key><string>${FFMPEG_VERSION}</string>
<key>CFBundleVersion</key><string>${FFMPEG_VERSION}</string>
<key>MinimumOSVersion</key><string>${MINVER}</string>
<key>CFBundleSupportedPlatforms</key><array><string>$([ "$SDKNAME" = iphoneos ] && echo iPhoneOS || echo iPhoneSimulator)</string></array>
</dict></plist>
EOF
# also keep a copy of the raw install headers for the headers zip
rm -rf "$OUT/include"; cp -R "$PREFIX/ffmpeg/include" "$OUT/include"
cp "$FW/Headers/FFmpegLGPL.h" "$OUT/include/"
cp "$WORK/ffmpeg/ffbuild/config.mak" "$OUT/ffmpeg-config.mak"
echo "built: $FW"; file "$FW/FFmpegLGPL"; ls -la "$FW/FFmpegLGPL"
