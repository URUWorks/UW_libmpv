#!/usr/bin/env python3
#
#  UW_libmpv
#
#  Checks that a DLL can load on Windows 7: it doesn't import functions or
#  API sets that only exist on Windows 8 and newer (Windows loads a DLL
#  only when all its imports exist, so one of them is enough to stop it).
#
#      pip install pefile
#      python tools/check_win7.py libmpv-2.dll
#
#  The contents of this file are used with permission, subject to
#  the Mozilla Public License Version 2.0 (the "License"); you may
#  not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#  http://www.mozilla.org/MPL/2.0.html
#
#  Copyright (C) 2026 URUWorks, uruworks@gmail.com.
#

import re
import sys

import pefile

# Windows 8+ functions that MinGW/LLVM builds pull in most often
WIN8 = {
    "GetSystemTimePreciseAsFileTime", "SetThreadDescription", "GetThreadDescription",
    "CreateFile2", "CopyFile2", "PrefetchVirtualMemory", "DiscardVirtualMemory",
    "OfferVirtualMemory", "ReclaimVirtualMemory", "GetCurrentThreadStackLimits",
    "WaitOnAddress", "WakeByAddressSingle", "WakeByAddressAll",
    "GetPackagePathByFullName", "GetPackageFamilyName", "GetCurrentPackageFullName",
    "GetCurrentPackageId", "CreateFileMappingFromApp", "MapViewOfFileFromApp",
    "VirtualAllocFromApp", "GetOverlappedResultEx", "LoadPackagedLibrary",
    "GetFirmwareType", "SetProcessDpiAwareness", "GetDpiForMonitor",
    "GetDpiForWindow", "GetDpiForSystem", "SetThreadDpiAwarenessContext",
    "SetProcessDpiAwarenessContext", "EnableNonClientDpiScaling",
    "AdjustWindowRectExForDpi", "GetSystemMetricsForDpi", "D3D11On12CreateDevice",
    "CreateDXGIFactory2", "DCompositionCreateDevice", "SetCoalescableTimer",
    "GetProcessMitigationPolicy", "SetProcessMitigationPolicy",
}

# API sets: the UCRT ones (api-ms-win-crt-*) come with the Universal CRT
# update for Windows 7 (KB2999226); the core ones of level 2 and up don't
CORE_NEW = re.compile(r"^api-ms-win-(core|shcore|power)-.*-l1-[2-9]-\d+\.dll$|^api-ms-win-core-.*-l[2-9]-", re.I)
WIN8_DLLS = {"shcore.dll", "d3d12.dll", "dcomp.dll", "mfplat.dll"}


def main():
    pe = pefile.PE(sys.argv[1], fast_load=True)
    pe.parse_data_directories(directories=[pefile.DIRECTORY_ENTRY["IMAGE_DIRECTORY_ENTRY_IMPORT"]])
    bad = []
    for entry in getattr(pe, "DIRECTORY_ENTRY_IMPORT", []):
        dll = entry.dll.decode()
        print(dll)
        if CORE_NEW.search(dll) or dll.lower() in WIN8_DLLS:
            bad.append(dll)
        for imp in entry.imports:
            name = imp.name.decode() if imp.name else ""
            if name in WIN8:
                bad.append("%s!%s" % (dll, name))
    if bad:
        print("FAIL: Windows 8+ imports: " + ", ".join(bad))
        sys.exit(1)
    print("OK: no Windows 8+ imports")


if __name__ == "__main__":
    main()
