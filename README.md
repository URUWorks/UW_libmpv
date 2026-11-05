# UW_libmpv

[libmpv](https://mpv.io) builds for [Tero Subtitler](https://github.com/URUWorks/TeroSubtitler)
and its video player ([UW_MPVPlayer](https://github.com/URUWorks/UW_MPVPlayer)), for
Windows and macOS, including the older systems.

Tero Subtitler downloads them from `releases/latest/download/<file>`, so a new release
is used without changing Tero Subtitler.

| File | System | Build |
|---|---|---|
| `libmpv2_win64.zip` | Windows 10 1607 and later, x64 | current, updated monthly |
| `libmpv2_winarm64.zip` | Windows 11 ARM64 | current, updated monthly |
| `libmpv2_win64_legacy.zip` | Windows 7 SP1 and 8.1, x64 | frozen (mpv 0.36.0-303, 2023-09-17) |
| `libmpv_macos.zip` | macOS 10.15 and later (Intel), 11 and later (Apple Silicon), universal | built here (mpv 0.40.0, FFmpeg 7.1.1) |
| `libmpv_macos_legacy.zip` | macOS 10.11 to 10.14 | frozen (mpv 0.35.0-419, universal) |

On Linux Tero Subtitler uses the libmpv of the system (for example `sudo apt install libmpv2`).

## Windows

The Windows builds are the libmpv (`libmpv-2.dll`) of
[shinchiro's mpv-winbuild-cmake](https://github.com/shinchiro/mpv-winbuild-cmake), the
build most Windows mpv players use.

- **Current**: on the 2nd of each month `.github/workflows/build.yml` looks for a new
  build. If there is one, it tests it and publishes a release (`v<date of the build>`).
- **ARM64**: built and tested (on `windows-11-arm`) with the x64 one, in every release.
  The x64 Tero Subtitler on Windows ARM runs emulated and uses the x64 DLL, so this one
  is for an ARM64 build of Tero Subtitler.
- **Legacy**: mpv needs Windows 8 and later since the end of 2023 (the builds after
  2023-09-17 import `GetSystemTimePreciseAsFileTime`), so the Windows 7/8.1 build is the
  one of 2023-09-17, checked by its SHA-256 and its imports (`tools/check_win7.py`). On
  Windows 7 SP1 it needs the Universal C Runtime (update KB2999226, it comes with the
  Visual C++ 2015 and later redistributable).

## macOS

Both zips have the dylibs at the root (Tero Subtitler extracts them next to its other
libraries).

- **Current**: a universal libmpv 2 (mpv 0.40.0, FFmpeg 7.1.1, libass, libplacebo) for
  macOS 10.15 (Intel) and 11 (Apple Silicon) and later, with the patches of
  `macos/patches` (mpv does not replace the menu bar of Tero Subtitler, and the open
  dialogs work on macOS 10.15). `.github/workflows/macos.yml` builds it from the sources
  of `macos/sources.txt` (fixed versions checked by SHA-256, updated by hand), each
  architecture on its own (`macos/build.sh`), joins them with `lipo` and signs them ad-hoc
  (`macos/package.sh`), checks the minimum macOS and that every dependency is in the zip
  (`macos/verify.sh`), and tests it on Apple Silicon, under Rosetta and on an Intel Mac.
  The Build workflow runs it for every release.
- **Legacy**: a universal libmpv 2 (mpv 0.35.0-419) with its libraries, for macOS 10.11
  and later. All the libraries are referenced with `@rpath`, nothing from Homebrew is
  needed. It's a frozen build.

## Tests

Every build is tested before it's published (`tools/test_libmpv.py` on Windows,
`macos/dltest.c` on macOS): it loads, it's libmpv 2 or later, it exports all the
functions UW_MPVPlayer uses, and it plays a short video and a short audio to the end.

## Workflows

- **Build** (`build.yml`): monthly, or Actions > Build > Run workflow (a given build with
  *upstream*, without a release with *publish* off).
- **macOS** (`macos.yml`): builds and tests `libmpv_macos.zip`. The Build workflow runs
  it; Actions > macOS > Run workflow builds it alone (the zip stays as an artifact).
- **Frozen builds** (`frozen.yml`): makes the Windows legacy zip and uploads it to the
  release `frozen`. The macOS legacy zip is uploaded to it by hand
  (`gh release upload frozen libmpv_macos_legacy.zip --clobber`). Every release includes
  the frozen builds.

## License

libmpv is GPL 2.0 or later (these builds include GPL parts), see
[mpv's license](https://github.com/mpv-player/mpv/blob/master/Copyright). The scripts of
this repository are MPL 2.0, as Tero Subtitler.
