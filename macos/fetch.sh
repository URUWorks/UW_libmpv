#!/bin/bash
# Downloads and checks the sources listed in sources.txt, applies the patches.
# Usage: macos/fetch.sh <workdir>
set -euo pipefail
H=$(cd "$(dirname "$0")" && pwd)
W=$1; S=$W/src
mkdir -p $S/dl
grep -v '^#' $H/sources.txt | while IFS='|' read -r name url sha; do
  [ -z "$name" ] && continue
  f=$S/dl/$(basename "$url")
  [ -f $f ] || curl -fsSL --retry 3 -o $f "$url"
  echo "$sha  $f" | shasum -a 256 -c -
  [ -d $S/$name ] || tar xf $f -C $S
done
if [ ! -d $S/libplacebo ]; then
  git clone -q --depth 1 --branch v7.351.0 --recurse-submodules --shallow-submodules \
    https://code.videolan.org/videolan/libplacebo.git $S/libplacebo
  [ "$(git -C $S/libplacebo rev-parse HEAD)" = 3188549fba13bbdf3a5a98de2a38c2e71f04e21e ]
fi
cd $S/mpv-0.40.0
for p in $H/patches/*.patch; do
  patch -p1 -N -l --dry-run -s < $p && patch -p1 -N -l -s < $p || echo "already applied: $p"
done
grep -q "if isApplication { DispatchQueue.main.sync" osdep/mac/app_hub.swift
grep -q "allowedFileTypes" osdep/mac/dialog.swift
