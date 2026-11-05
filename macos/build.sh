#!/bin/zsh
# Builds libmpv and its dependencies for one architecture.
# Usage: MIN=<macOS> arch -<ARCH> /bin/zsh macos/build.sh <arm64|x86_64> <workdir>
# (run fetch.sh and tools.sh first)
set -euo pipefail
A=$1
W=$2
S=$W/src
B=$W/build/$A
P=$W/prefix/$A
T=$W/tools
mkdir -p $B $P

export PATH=$T/bin:$T/venv/bin:/usr/bin:/bin:/usr/sbin:/sbin
MIN=${MIN:-11.0}
export MACOSX_DEPLOYMENT_TARGET=$MIN
export CC="clang -arch $A" CXX="clang++ -arch $A" OBJC="clang -arch $A"
export CFLAGS="-O2 -mmacosx-version-min=$MIN"
export CXXFLAGS="$CFLAGS" OBJCFLAGS="$CFLAGS"
export LDFLAGS="-mmacosx-version-min=$MIN -headerpad_max_install_names -L$P/lib"
export CPPFLAGS="-I$P/include"
export PKG_CONFIG_LIBDIR=$P/lib/pkgconfig PKG_CONFIG_PATH=
J=$(sysctl -n hw.ncpu)

msetup() { # srcdir builddir [opts...]
  local src=$1 bld=$2; shift 2
  rm -rf $bld
  meson setup $bld $src --prefix=$P --libdir=lib --buildtype=release \
    --default-library=shared -Db_ndebug=true "$@"
  ninja -C $bld -j$J install
}

STEPS=(freetype fribidi harfbuzz libass ffmpeg libplacebo mpv)
FROM=${FROM:-freetype}
step() { # skip until $FROM is reached
  (( ${STEPS[(Ie)$1]} >= ${STEPS[(Ie)$FROM]} )) || return 1
  echo "\n===== [$A] $1 =====" ; }

if step freetype; then
msetup $S/freetype-2.13.3 $B/freetype -Dzlib=internal -Dpng=disabled \
  -Dbzip2=disabled -Dbrotli=disabled -Dharfbuzz=disabled -Dtests=disabled
fi

if step fribidi; then
msetup $S/fribidi-1.0.16 $B/fribidi -Ddocs=false -Dtests=false -Dbin=false
fi

if step harfbuzz; then
msetup $S/harfbuzz-10.4.0 $B/harfbuzz -Dfreetype=enabled -Dglib=disabled \
  -Dgobject=disabled -Dcairo=disabled -Dchafa=disabled -Dicu=disabled \
  -Dgraphite2=disabled -Dtests=disabled -Ddocs=disabled -Dutilities=disabled \
  -Dintrospection=disabled -Dcoretext=disabled
fi

if step libass; then
rm -rf $B/libass; mkdir -p $B/libass; cd $B/libass
$S/libass-0.17.3/configure --prefix=$P --enable-shared --disable-static \
  --disable-fontconfig --enable-coretext --disable-require-system-font-provider \
  --disable-libunibreak --host=$( [[ $A == arm64 ]] && echo aarch64 || echo x86_64 )-apple-darwin
make -j$J
make install
fi

if step ffmpeg; then
rm -rf $B/ffmpeg; mkdir -p $B/ffmpeg; cd $B/ffmpeg
$S/ffmpeg-7.1.1/configure --prefix=$P --arch=$A --cc="clang -arch $A" \
  --cxx="clang++ -arch $A" --objcc="clang -arch $A" \
  --extra-cflags="$CFLAGS" --extra-ldflags="$LDFLAGS" \
  --enable-shared --disable-static --disable-programs --disable-doc \
  --disable-debug --enable-pic --enable-videotoolbox --enable-audiotoolbox \
  --disable-sdl2 --disable-xlib --disable-libxcb --disable-avdevice \
  --disable-postproc --pkg-config=pkg-config \
  --install-name-dir='@rpath'
make -j$J
make install
fi

if step libplacebo; then
msetup $S/libplacebo $B/libplacebo -Dvulkan=disabled -Dopengl=enabled \
  -Dd3d11=disabled -Dglslang=disabled -Dshaderc=disabled -Dlcms=disabled \
  -Ddovi=disabled -Dlibdovi=disabled -Ddemos=false -Dtests=false -Dbench=false \
  -Dfuzz=false -Dunwind=disabled -Dxxhash=disabled
fi

if step mpv; then
LDFLAGS="$LDFLAGS -Wl,-weak_framework,UniformTypeIdentifiers" msetup $S/mpv-0.40.0 $B/mpv -Dlibmpv=true -Dcplayer=false -Dlua=disabled \
  -Djavascript=disabled -Dswift-build=enabled -Dmacos-media-player=disabled \
  -Dswift-flags="-target $( [[ $A == arm64 ]] && echo arm64 || echo x86_64 )-apple-macos$MIN" \
  -Dmanpage-build=disabled -Dvulkan=disabled -Dsdl2-audio=disabled \
  -Dsdl2-video=disabled -Dsdl2-gamepad=disabled -Dlibavdevice=disabled \
  -Dlibarchive=disabled -Duchardet=disabled -Dlcms2=disabled -Djpeg=disabled \
  -Dcdda=disabled -Ddvdnav=disabled -Dlibbluray=disabled -Drubberband=disabled \
  -Dzimg=disabled -Dvapoursynth=disabled
fi

echo "\n===== [$A] DONE ====="
