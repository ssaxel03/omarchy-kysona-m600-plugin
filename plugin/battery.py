#!/usr/bin/env python3
"""Read the Kysona M600 battery from sysfs (wired) or hidraw (2.4 GHz dongle)."""

import glob
import json
import os
import select
import sys
import time

BY_ID = "/dev/input/by-id/usb-CX_2.4G_Wireless_Receiver-if01-hidraw"
REQUEST = bytes([0x08, 0x04] + [0x00] * 14 + [0x49])
TIMEOUT = 3.0

# mV at 0%, 5%, ... 100%, from the M600 V2 vendor driver. Same curve as
# OpenKysona's src/lib/protocol/battery.ts.
CURVE_MV = [
    3050, 3420, 3480, 3540, 3600, 3660, 3720, 3760, 3800, 3840, 3880, 3920,
    3940, 3960, 3980, 4000, 4020, 4040, 4060, 4080, 4110,
]


def percent_from_millivolts(millivolts):
    if millivolts <= CURVE_MV[0]:
        return 0
    for index in range(1, len(CURVE_MV)):
        low, high = CURVE_MV[index - 1], CURVE_MV[index]
        if millivolts <= high:
            return (index - 1) * 5 + ((millivolts - low) * 5) // (high - low)
    return 100


def read_sysfs():
    """The in-tree kysona driver exposes battery data when the mouse is wired."""
    for path in sorted(glob.glob("/sys/class/power_supply/kysona-*-battery")):
        try:
            values = {}
            for key in ("capacity", "status", "online", "present", "voltage_now"):
                with open(os.path.join(path, key), "r", encoding="ascii") as handle:
                    values[key] = handle.read().strip()
        except OSError:
            continue
        if values["present"] != "1":
            continue
        try:
            capacity = int(values["capacity"])
            voltage = int(values["voltage_now"])
        except ValueError:
            continue
        if not 0 <= capacity <= 100 or voltage <= 0:
            continue
        # This V2 mouse reports status=Unknown and online=0 while charging over
        # USB-C, even though capacity and voltage are live. USB-C power means
        # charging unless the driver explicitly says Discharging.
        charging = values["status"] != "Discharging"
        millivolts = voltage // 1000
        return {
            "available": True,
            "percentage": capacity,
            "charging": charging,
            "voltage": round(millivolts / 1000.0, 3),
            "millivolts": millivolts,
            "voltageLevel": percent_from_millivolts(millivolts),
            "source": "wired",
            "error": "",
        }
    return None


def fallback_path():
    """Find interface 1 of the receiver when the by-id symlink is absent."""
    base = "/sys/class/hidraw"
    try:
        names = sorted(os.listdir(base))
    except OSError:
        return None
    for name in names:
        uevent = os.path.join(base, name, "device", "uevent")
        try:
            with open(uevent, "r", encoding="ascii") as handle:
                fields = dict(
                    line.split("=", 1)
                    for line in handle.read().splitlines()
                    if "=" in line
                )
        except OSError:
            continue
        if fields.get("HID_PHYS", "").endswith("/input1") and (
            "00003554" in fields.get("HID_ID", "")
            and "0000F5D5" in fields.get("HID_ID", "")
        ):
            return os.path.join("/dev", name)
    return None


def read_hidraw():
    path = BY_ID if os.path.exists(BY_ID) else fallback_path()
    if not path:
        return {"available": False, "error": "receiver not found"}

    try:
        fd = os.open(path, os.O_RDWR | os.O_NONBLOCK)
    except OSError as exc:
        return {"available": False, "error": str(exc)}

    try:
        deadline = time.monotonic() + TIMEOUT
        next_send = 0.0
        while time.monotonic() < deadline:
            now = time.monotonic()
            if now >= next_send:
                try:
                    os.write(fd, REQUEST)
                except OSError as exc:
                    return {"available": False, "error": str(exc)}
                next_send = now + 1.0
            ready, _, _ = select.select([fd], [], [], 0.2)
            if not ready:
                continue
            try:
                data = os.read(fd, 64)
            except OSError:
                continue
            if len(data) != 17 or data[0] != 0x08 or data[1] != 0x04:
                continue
            capacity = data[6]
            if capacity > 100:
                continue
            voltage = (data[8] << 8) | data[9]
            return {
                "available": True,
                "percentage": capacity,
                "charging": bool(data[7]),
                "voltage": round(voltage / 1000.0, 3),
                "millivolts": voltage,
                "voltageLevel": percent_from_millivolts(voltage),
                "source": "wireless",
                "error": "",
            }
        return {"available": False, "error": "mouse is off or unreachable"}
    finally:
        os.close(fd)


def main():
    try:
        result = read_sysfs() or read_hidraw()
    except Exception as exc:  # keep the shell alive on unexpected device states
        result = {"available": False, "error": "{}: {}".format(type(exc).__name__, exc)}
    sys.stdout.write(json.dumps(result) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
