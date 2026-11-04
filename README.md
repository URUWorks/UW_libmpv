# UW_libmpv

[libmpv](https://mpv.io) builds for [Tero Subtitler](https://github.com/URUWorks/TeroSubtitler)
and its video player ([UW_MPVPlayer](https://github.com/URUWorks/UW_MPVPlayer)), for
Windows and macOS, including the older systems.

Tero Subtitler downloads them from `releases/latest/download/<file>`, so a new release
is used without changing Tero Subtitler.

| File | System | Build |
|---|---|---|
| `libmpv2_win64.zip` | Windows 10 1607 and later, x64 | current, updated monthly |
| `libmpv2_win64_legacy.zip` | Windows 7 SP1 and 8.1, x64 | frozen (mpv 0.36.0-303, 2023-09-17) |
| `libmpv_macos.zip` | macOS 10.15 and later (Intel), 11 and later (Apple Silicon), universal | frozen (mpv 0.40.0) until it is built here |
| `libmpv_macos_legacy.zip` | macOS 10.11 to 10.14 | frozen (mpv 0.35.0-419, universal) |
| `libmpv2_winarm64.zip` | Windows 11 ARM64 | ready, off until Tero Subtitler has an ARM64 build |

On Linux Tero Subtitler uses the libmpv of the system (for example `sudo apt install libmpv2`).

## Windows

The Windows builds are the libmpv (`libmpv-2.dll`) of
[shinchiro's mpv-winbuild-cmake](https://github.com/shinchiro/mpv-winbuild-cmake), the
build most Windows mpv players use.

- **Current**: on the 2nd of each month `.github/workflows/build.yml` looks for a new
  build. If there is one, it tests it and publishes a release (`v<date of the build>`).
- **Legacy**: mpv needs Windows 8 and later since the end of 2023 (the builds after
  2023-09-17 import `GetSystemTimePreciseAsFileTime`), so the Windows 7/8.1 build is the
  one of 2023-09-17, checked by its SHA-256 and its imports (`tools/check_win7.py`). On
  Windows 7 SP1 it needs the Universal C Runtime (update KB2999226, it comes with the
  Visual C++ 2015 and later redistributable).
- **ARM64**: Actions > Build > Run workflow with *winarm64*, or the repository variable
  `WINARM64 = true`. The x64 Tero Subtitler on Windows ARM runs emulated and needs the
  x64 DLL, so this is only for an ARM64 build of Tero Subtitler.

## macOS

- **Legacy**: a universal libmpv 2 (mpv 0.35.0-419) with its libraries, for macOS 10.11
  and later. All the libraries are referenced with `@rpath`, nothing from Homebrew is
  needed.
- **Current**: a universal libmpv 2 (mpv 0.40.0, FFmpeg 7.1.1) for macOS 10.15 (Intel) and
  11 (Apple Silicon) and later, with the patches for the menu bar and the macOS 10.15
  dialogs. To be built here with the mpvbuild scripts; until then it's a frozen build.

## Tests

Every build is tested before it's published (`tools/test_libmpv.py`): it loads, it's
libmpv 2 or later, it exports all the functions UW_MPVPlayer uses, and it plays a short
video and a short audio to the end.

## Workflows

- **Build** (`build.yml`): monthly, or Actions > Build > Run workflow (a given build with
  *upstream*, without a release with *publish* off).
- **Frozen builds** (`frozen.yml`): makes the Windows legacy zip and uploads it to the
  release `frozen`. The macOS zips are uploaded to it by hand
  (`gh release upload frozen <zip> --clobber`). Every release includes the frozen builds.

## License

libmpv is GPL 2.0 or later (these builds include GPL parts), see
[mpv's license](https://github.com/mpv-player/mpv/blob/master/Copyright). The scripts of
this repository are MPL 2.0, as Tero Subtitler.
