#!/bin/bash
# Checks the packaged dylibs: both archs, minimum macOS, signatures and that
# every non-system dependency is in the folder. Fails on any problem.
# Usage: macos/verify.sh <Frameworks folder> <min arm64> <min x86_64>
set -uo pipefail
cd "$1"; MA=$2; MX=$3; bad=0
printf "%-26s %-7s %-7s %s\n" dylib arm64 x86_64 archs
for f in *.dylib; do
  a=$(otool -arch arm64 -l $f | awk '/LC_BUILD_VERSION/{f=1} f&&/minos/{print $2;exit}')
  x=$(otool -arch x86_64 -l $f | awk '/LC_BUILD_VERSION/{f=1} f&&/minos/{print $2;exit} /LC_VERSION_MIN_MACOSX/{g=1} g&&/ version/{print $2;exit}')
  printf "%-26s %-7s %-7s %s\n" $f "$a" "$x" "$(lipo -archs $f)"
  [ "$a" = "$MA" ] || { echo "  BAD arm64 minimum: $a"; bad=1; }
  [ "$x" = "$MX" ] || { echo "  BAD x86_64 minimum: $x"; bad=1; }
  for A in arm64 x86_64; do
    otool -arch $A -l $f | grep -q LC_DYLD_CHAINED_FIXUPS && { echo "  BAD chained fixups ($A)"; bad=1; }
    for d in $(otool -arch $A -L $f | tail -n +2 | awk '{print $1}'); do
      case $d in
        /usr/lib/*|/System/*) ;;
        @loader_path/*|@rpath/*) [ -f "$(basename $d)" ] || { echo "  BAD missing $d"; bad=1; } ;;
        *) echo "  BAD dependency $d"; bad=1 ;;
      esac
    done
  done
  codesign -v $f 2>/dev/null || { echo "  BAD signature"; bad=1; }
done
echo "--- strong swift/UTI loads in libmpv x86_64:"
otool -arch x86_64 -l libmpv.2.dylib | grep -A2 " LC_LOAD_DYLIB" | grep -E "Uniform" && { echo "  BAD UniformTypeIdentifiers must be weak"; bad=1; } || echo none
[ $bad = 0 ] && echo "ALL OK" || echo "FAILED"
exit $bad
