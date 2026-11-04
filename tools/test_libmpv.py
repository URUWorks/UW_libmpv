#!/usr/bin/env python3
#
#  UW_libmpv
#
#  Checks a libmpv for Tero Subtitler (UW_MPVPlayer): it loads, it is
#  libmpv 2 or newer, it exports every function UW_MPVPlayer uses, and it
#  plays a short video and a short audio to the end (without video or
#  audio output, so it works on the build machines).
#
#      python tools/test_libmpv.py <path to libmpv-2.dll / libmpv.2.dylib>
#
#  The contents of this file are used with permission, subject to
#  the Mozilla Public License Version 2.0 (the "License"); you may
#  not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#  http://www.mozilla.org/MPL/2.0.html
#
#  Copyright (C) 2026 URUWorks, uruworks@gmail.com.
#

import ctypes
import math
import os
import struct
import sys
import tempfile
import time
import wave

# the functions UW_MPVPlayer loads (libMPV.Client.pas, libMPV.Render.pas)
FUNCTIONS = """
mpv_abort_async_command mpv_client_api_version mpv_client_id mpv_client_name
mpv_command mpv_command_async mpv_command_node mpv_command_node_async
mpv_command_ret mpv_command_string mpv_create mpv_create_client
mpv_create_weak_client mpv_destroy mpv_error_string mpv_event_name
mpv_event_to_node mpv_free mpv_free_node_contents mpv_get_property
mpv_get_property_async mpv_get_property_osd_string mpv_get_property_string
mpv_get_time_us mpv_get_wakeup_pipe mpv_hook_add mpv_hook_continue
mpv_initialize mpv_load_config_file mpv_observe_property mpv_request_event
mpv_request_log_messages mpv_set_option mpv_set_option_string
mpv_set_property mpv_set_property_async mpv_set_property_string
mpv_set_wakeup_callback mpv_terminate_destroy mpv_unobserve_property
mpv_wait_async_requests mpv_wait_event mpv_wakeup
mpv_render_context_create mpv_render_context_free mpv_render_context_get_info
mpv_render_context_render mpv_render_context_report_swap
mpv_render_context_set_parameter mpv_render_context_set_update_callback
mpv_render_context_update
""".split()

MPV_EVENT_SHUTDOWN = 1
MPV_EVENT_END_FILE = 7
MPV_END_FILE_REASON_EOF = 0


class MpvEvent(ctypes.Structure):
    _fields_ = [("event_id", ctypes.c_int), ("error", ctypes.c_int),
                ("reply_userdata", ctypes.c_uint64), ("data", ctypes.c_void_p)]


class MpvEventEndFile(ctypes.Structure):
    _fields_ = [("reason", ctypes.c_int), ("error", ctypes.c_int)]


def fail(msg):
    print("FAIL: " + msg)
    sys.exit(1)


def make_y4m(path, w=160, h=120, frames=25):
    """A raw YUV4MPEG2 video, one second, a moving gray ramp."""
    with open(path, "wb") as f:
        f.write(b"YUV4MPEG2 W%d H%d F25:1 Ip A1:1 C420jpeg\n" % (w, h))
        for n in range(frames):
            f.write(b"FRAME\n")
            f.write(bytes(((x + n * 8) & 0xFF) for _ in range(h) for x in range(w)))
            f.write(b"\x80" * (w * h // 2))


def make_wav(path, rate=44100, seconds=1):
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(b"".join(struct.pack("<h", int(8000 * math.sin(i * 2 * math.pi * 440 / rate)))
                               for i in range(rate * seconds)))


def main():
    if len(sys.argv) != 2:
        fail("usage: test_libmpv.py <libmpv>")
    lib_path = os.path.abspath(sys.argv[1])
    if sys.platform == "win32":
        os.add_dll_directory(os.path.dirname(lib_path))
    try:
        lib = ctypes.CDLL(lib_path)
    except OSError as e:
        fail("can't load %s: %s" % (lib_path, e))

    missing = [f for f in FUNCTIONS if not hasattr(lib, f)]
    if missing:
        fail("missing functions: " + " ".join(missing))
    print("OK: the %d functions of UW_MPVPlayer are exported" % len(FUNCTIONS))

    lib.mpv_client_api_version.restype = ctypes.c_ulong
    api = lib.mpv_client_api_version()
    print("client API %d.%d" % (api >> 16, api & 0xFFFF))
    if api >> 16 < 2:
        fail("libmpv 2 or newer is needed")

    lib.mpv_create.restype = ctypes.c_void_p
    lib.mpv_set_option_string.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_char_p]
    lib.mpv_initialize.argtypes = [ctypes.c_void_p]
    lib.mpv_command.argtypes = [ctypes.c_void_p, ctypes.POINTER(ctypes.c_char_p)]
    lib.mpv_wait_event.argtypes = [ctypes.c_void_p, ctypes.c_double]
    lib.mpv_wait_event.restype = ctypes.POINTER(MpvEvent)
    lib.mpv_get_property_string.argtypes = [ctypes.c_void_p, ctypes.c_char_p]
    lib.mpv_get_property_string.restype = ctypes.c_void_p
    lib.mpv_free.argtypes = [ctypes.c_void_p]
    lib.mpv_terminate_destroy.argtypes = [ctypes.c_void_p]

    h = lib.mpv_create()
    if not h:
        fail("mpv_create")
    for k, v in (("vo", "null"), ("ao", "null"), ("config", "no"), ("terminal", "no"),
                 ("idle", "yes"), ("audio-display", "no")):
        lib.mpv_set_option_string(h, k.encode(), v.encode())
    if lib.mpv_initialize(h) < 0:
        fail("mpv_initialize")

    p = lib.mpv_get_property_string(h, b"mpv-version")
    if p:
        print(ctypes.string_at(p).decode(errors="replace"))
        lib.mpv_free(p)

    tmp = tempfile.mkdtemp()
    files = [os.path.join(tmp, "test.y4m"), os.path.join(tmp, "test.wav")]
    make_y4m(files[0])
    make_wav(files[1])

    for path in files:
        args = (ctypes.c_char_p * 3)(b"loadfile", path.encode("utf-8"), None)
        if lib.mpv_command(h, args) < 0:
            fail("loadfile " + path)
        end = time.time() + 30
        while True:
            if time.time() > end:
                fail("timeout playing " + path)
            ev = lib.mpv_wait_event(h, 1.0).contents
            if ev.event_id == MPV_EVENT_SHUTDOWN:
                fail("shutdown while playing " + path)
            if ev.event_id == MPV_EVENT_END_FILE:
                ef = ctypes.cast(ev.data, ctypes.POINTER(MpvEventEndFile)).contents
                if ef.reason != MPV_END_FILE_REASON_EOF or ef.error < 0:
                    fail("%s ended with reason %d, error %d" % (path, ef.reason, ef.error))
                print("OK: played %s to the end" % os.path.basename(path))
                break

    lib.mpv_terminate_destroy(h)
    print("OK")


if __name__ == "__main__":
    main()
