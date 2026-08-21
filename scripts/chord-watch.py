#!/usr/bin/env python3
"""Chord watcher for the makima-mx profile switcher.

Watches the physical mouse for the Back+Forward chord and, while it is held,
reports scroll ticks. Prints line events on stdout for the Quickshell side:

    DOWN        both chord buttons went down
    SCROLL +1   wheel-up detent while chord held
    SCROLL -1   wheel-down detent while chord held
    UP          chord released

Why this shape: makima holds an exclusive grab on the physical mouse, so we
can't read its events — but the kernel still answers the EVIOCGKEY state
ioctl, which is enough to see the chord. Scroll events can't be seen on the
physical device, but makima re-emits them on its virtual pointer
(REL_WHEEL_HI_RES), which is group-readable. Node paths are re-resolved by
device name on every failure, since makima restarts recreate its virtual
device and reconnects renumber the physical one.

Usage: chord-watch.py [physical-device-name] [virtual-device-name]
"""
import fcntl
import os
import struct
import sys
import time

PHYS_NAME = sys.argv[1] if len(sys.argv) > 1 else "Logitech USB Receiver Mouse"
VIRT_NAME = sys.argv[2] if len(sys.argv) > 2 else "Makima Virtual Pointer"
CHORD = (275, 276)  # BTN_SIDE (back), BTN_EXTRA (forward)

POLL_S = 0.03
KEY_MAX = 0x2FF
NBYTES = (KEY_MAX + 7) // 8
EVIOCGKEY = (2 << 30) | (NBYTES << 16) | (ord("E") << 8) | 0x18
EV_REL, REL_WHEEL, REL_WHEEL_HI_RES, DETENT = 0x02, 0x08, 0x0B, 120
EVIOCGRAB = (1 << 30) | (4 << 16) | (ord("E") << 8) | 0x90
EVENT_FMT = "qqHHi"  # struct input_event on 64-bit
EVENT_SIZE = struct.calcsize(EVENT_FMT)


def find_nodes(name):
    """All /dev/input/eventN nodes whose device name matches (there can be
    several — makima creates one virtual set per config device)."""
    try:
        with open("/proc/bus/input/devices") as f:
            text = f.read()
    except OSError:
        return []
    nodes = []
    current = None
    for line in text.splitlines():
        if line.startswith("N: Name="):
            current = line.split("=", 1)[1].strip('"')
        elif line.startswith("H: Handlers=") and current == name:
            for handler in line.split("=", 1)[1].split():
                if handler.startswith("event"):
                    nodes.append("/dev/input/" + handler)
    return nodes


def open_by_name(name):
    """First matching node, opened non-blocking (physical device)."""
    for node in find_nodes(name):
        try:
            return os.open(node, os.O_RDONLY | os.O_NONBLOCK)
        except OSError:
            continue
    return None


def open_all_by_name(name, grab=False):
    """Every matching node, opened non-blocking (virtual devices).

    With grab=True the nodes are EVIOCGRAB'd: while the chord is held, scroll
    and pointer motion are diverted to us instead of reaching applications —
    the switcher becomes modal. The kernel releases the grab automatically
    when the fd closes (including if this process dies)."""
    fds = []
    for node in find_nodes(name):
        try:
            fd = os.open(node, os.O_RDONLY | os.O_NONBLOCK)
        except OSError:
            continue
        if grab:
            try:
                fcntl.ioctl(fd, EVIOCGRAB, 1)
            except OSError:
                pass
        fds.append(fd)
    return fds


def close_quiet(fd):
    if fd is not None:
        try:
            os.close(fd)
        except OSError:
            pass


def emit(line):
    print(line, flush=True)


def main():
    phys = None
    virts = []
    buf = bytearray(NBYTES)
    held = False
    accum = 0
    while True:
        if phys is None:
            phys = open_by_name(PHYS_NAME)
            if phys is None:
                time.sleep(1.0)
                continue
        try:
            fcntl.ioctl(phys, EVIOCGKEY, buf)
        except OSError:
            close_quiet(phys)
            phys = None
            if held:
                held = False
                emit("UP")
            continue
        down = all(buf[c // 8] >> (c % 8) & 1 for c in CHORD)
        if down and not held:
            held = True
            accum = 0
            # Open fresh so we only see scroll that happens during the hold.
            for fd in virts:
                close_quiet(fd)
            virts = open_all_by_name(VIRT_NAME, grab=True)
            emit("DOWN")
        elif not down and held:
            held = False
            for fd in virts:
                close_quiet(fd)
            virts = []
            emit("UP")
        if held:
            for fd in list(virts):
                while True:
                    try:
                        chunk = os.read(fd, EVENT_SIZE * 64)
                    except BlockingIOError:
                        break
                    except OSError:
                        close_quiet(fd)
                        virts.remove(fd)
                        break
                    if not chunk:
                        break
                    for off in range(0, len(chunk) - EVENT_SIZE + 1, EVENT_SIZE):
                        _, _, etype, code, value = struct.unpack_from(EVENT_FMT, chunk, off)
                        if etype == EV_REL and code in (REL_WHEEL, REL_WHEEL_HI_RES):
                            accum += value * (DETENT if code == REL_WHEEL else 1)
                            while accum >= DETENT:
                                accum -= DETENT
                                emit("SCROLL +1")
                            while accum <= -DETENT:
                                accum += DETENT
                                emit("SCROLL -1")
        time.sleep(POLL_S)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        pass
