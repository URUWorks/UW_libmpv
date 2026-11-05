#!/bin/zsh
# Relocates the per-arch dylibs of <workdir>/prefix/{arm64,x86_64}, joins them
# with lipo and signs them ad-hoc in <workdir>/out/Frameworks.
# Usage: /bin/zsh macos/package.sh <workdir>
set -euo pipefail
H=${0:A:h}
W=$1
ARCHS=(arm64 x86_64)
STAGE=$W/stage
FW=$W/out/Frameworks
rm -rf $STAGE $FW; mkdir -p $FW

collect() { # arch -> prints real dylib paths
  local P=$W/prefix/$1
  for f in $P/lib/*.dylib; do
    [[ -L $f || $f == *harfbuzz-subset* ]] && continue
    echo $f
  done
}

for A in $ARCHS; do
  mkdir -p $STAGE/$A
  for f in $(collect $A); do
    n=$(basename "$(otool -D $f | tail -1)")
    cp $f $STAGE/$A/$n
    chmod u+w $STAGE/$A/$n
  done
  NAMES=(${(f)"$(ls $STAGE/$A)"})
  for n in $NAMES; do
    f=$STAGE/$A/$n
    install_name_tool -id @rpath/$n $f 2>/dev/null
    for dep in $(otool -L $f | tail -n +2 | awk '{print $1}'); do
      b=$(basename $dep)
      [[ $b == $n ]] && continue
      if (( ${NAMES[(Ie)$b]} )); then
        install_name_tool -change $dep @loader_path/$b $f 2>/dev/null
      fi
    done
    # drop the LC_RPATH of the build prefix, keep the Swift runtime one
    for rp in $(otool -l $f | awk '/LC_RPATH/{getline;getline;print $2}'); do
      [[ $rp == /usr/lib/swift ]] || install_name_tool -delete_rpath $rp $f 2>/dev/null
    done
  done
done

for n in $(ls $STAGE/arm64); do
  [[ -f $STAGE/x86_64/$n ]] || { echo "missing x86_64/$n"; exit 1; }
  lipo -create $STAGE/arm64/$n $STAGE/x86_64/$n -output $FW/$n
done
codesign -f -s - $FW/*.dylib(.)
cp $H/patches/*.patch $FW/

if otool -L $FW/*.dylib(.) | grep -q "$W"; then
  echo "ERROR: build-tree paths remain"; otool -L $FW/*.dylib(.) | grep "$W"; exit 1
fi
echo "packaged:"; ls -l $FW
