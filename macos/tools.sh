#!/bin/bash
# Build tools in <workdir>/tools: meson/ninja (venv), nasm, pkgconf.
set -euo pipefail
W=$1; T=$W/tools; S=$W/src
mkdir -p $T
# a universal python (/usr/bin/python3), so meson runs as x86_64 under Rosetta
[ -x $T/venv/bin/python ] || ${PYTHON:-/usr/bin/python3} -m venv $T/venv
[ -x $T/venv/bin/meson ] || $T/venv/bin/pip install -q meson==1.11.2 ninja==1.13.2
export PATH=$T/bin:$T/venv/bin:/usr/bin:/bin:/usr/sbin:/sbin
if [ ! -x $T/bin/nasm ]; then
  mkdir -p $W/build; rm -rf $W/build/nasm; cp -Rp $S/nasm-2.16.03 $W/build/nasm
  (cd $W/build/nasm && ./configure -q --prefix=$T && make -j8 && make install)
fi
if [ ! -x $T/bin/pkgconf ]; then
  meson setup $W/build/pkgconf $S/pkgconf-2.3.0 -Dprefix=$T -Dtests=disabled
  ninja -C $W/build/pkgconf install
  ln -sf pkgconf $T/bin/pkg-config
fi
