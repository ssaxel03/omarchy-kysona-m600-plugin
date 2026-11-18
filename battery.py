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

# Resting (unplugged) voltage lookup. Charging lifts the measured voltage, so
# subtract CHARGE_OFFSET_MV before using this table while charging.
RESTING_TABLE = [
    (3300, 0), (3500, 5), (3700, 15), (3780, 30), (3850, 50),
    (3950, 70), (4060, 85), (4200, 100),
]
CHARGE_OFFSET_MV = 80
FULL_MV = 4180


def percent_from_voltage(millivolts, charging, wired):
    if wired and millivolts >= FULL_MV:
        return 100
    if charging and millivolts < FULL_MV:
        millivolts -= CHARGE_OFFSET_MV
    if millivolts <= RESTING_TABLE[0][0]:
        return 0
    for (low_mv, low_pct), (high_mv, high_pct) in zip(RESTING_TABLE, RESTING_TABLE[1:]):
        if millivolts <= high_mv:
            return low_pct + ((millivolts - low_mv) * (high_pct - low_pct)) // (high_mv - low_mv)
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
        level = percent_from_voltage(millivolts, charging, True)
        if millivolts >= FULL_MV:
            charging = False
        return {
            "available": True,
            "percentage": capacity,
            "charging": charging,
            "voltage": round(millivolts / 1000.0, 3),
            "millivolts": millivolts,
            "voltageLevel": level,
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
                "voltageLevel": percent_from_voltage(voltage, bool(data[7]), False),
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
