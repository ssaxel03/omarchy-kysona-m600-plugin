# Phase 0 findings — feasibility

Date: 2026-11-18. Machine: Omarchy, kernel `7.2.15-1-omarchy`, UPower 1.91.5.
Mouse: Kysona M600 (confirmed by user).

Commands were run read-only. No device was bound, unbound, or written to.

## 1. Kernel support is present

```
$ uname -r
7.2.15-1-omarchy

$ lsmod | grep -i kysona
hid_kysona             20480  0

$ ls /sys/bus/hid/drivers/
hid-generic
kysona
```

The module is loaded but its refcount is `0`: no device is bound to it right now.

```
$ modinfo hid_kysona
filename:       /lib/modules/7.2.15-1-omarchy/kernel/drivers/hid/hid-kysona.ko.zst
author:         Lode Willems <me@lodewillems.com>
description:    HID driver for Kysona devices
alias:          hid:b0003g*v00003554p0000F58C
alias:          hid:b0003g*v00003554p0000F58A
alias:          hid:b0003g*v00003554p0000F57D
alias:          hid:b0003g*v00003554p0000F57C
```

Supported USB IDs on this kernel: `3554:F57C` (dongle), `3554:F57D` (wired),
`3554:F58A`, `3554:F58C`.

## 2. The currently plugged receiver is not supported

```
$ lsusb
...
Bus 003 Device 005: ID 3554:f5d5 CX 2.4G Wireless Receiver
...

$ grep -H . /sys/class/hidraw/hidraw*/device/uevent
/sys/class/hidraw/hidraw1/device/uevent:DRIVER=hid-generic
/sys/class/hidraw/hidraw1/device/uevent:HID_ID=0003:00003554:0000F5D5
/sys/class/hidraw/hidraw1/device/uevent:HID_NAME=CX 2.4G Wireless Receiver
/sys/class/hidraw/hidraw2/device/uevent:DRIVER=hid-generic
/sys/class/hidraw/hidraw2/device/uevent:HID_ID=0003:00003554:0000F5D5
/sys/class/hidraw/hidraw2/device/uevent:HID_NAME=CX 2.4G Wireless Receiver
```

`F5D5` is not in the driver's alias list. Both of its HID interfaces are claimed
by `hid-generic`, so no battery device is created for it. With this receiver in
use, the widget cannot get battery data from the kernel driver.

## 3. The supported device has been seen on this machine

Kernel log from Nov 17, 22:53:

```
usb 3-4: New USB device found, idVendor=3554, idProduct=f57d, bcdDevice= 3.10
input: Compx KSN M600 V2 as .../input/input27
hid-generic 0003:3554:F57D.0008: input,hidraw5: USB HID v1.11 Keyboard [Compx KSN M600 V2]
kysona 0003:3554:F57D.0008: input,hidraw5: USB HID v1.11 Keyboard [Compx KSN M600 V2]
kysona 0003:3554:F57D.0009: input,hiddev100,hidraw6: USB HID v1.11 Device [Compx KSN M600 V2]
kysona 0003:3554:F57D.000A: input,hidraw7: USB HID v1.11 Mouse [Compx KSN M600 V2]
```

So a wired M600 appears as `3554:F57D` ("Compx KSN M600 V2") and the `kysona`
driver binds to all three interfaces. That device is unplugged now.

## 4. No battery device exists while the mouse is disconnected

```
$ ls -la /sys/class/power_supply/
total 0
drwxr-xr-x 2 root root 0 Nov 18 01:52 .
drwxr-xr-x 1 root root 0 Nov 15 11:21 ..

$ upower -e
/org/freedesktop/UPower/devices/DisplayDevice
```

This was written while no supported device was connected. Later testing showed
the in-use dongle never creates a `power_supply` device, so UPower does not
expose this battery. See the hidraw test below.

## 5. What the driver exposes when it is connected

From the upstream driver patch (source in Sources below):

- Registers a `power_supply` device only on USB interface 1 of a supported ID.
- Name: `kysona-<uniq-or-dev_name>-battery`, for example
  `kysona-0003:3554:F57D.0009-battery` when `uniq` is empty.
- Properties: `status`, `present`, `capacity`, `scope`, `model_name`,
  `voltage_now`, `online`.
- Polls the mouse every 5 seconds with a workqueue.
- `online` stays false until the mouse answers a battery request. This prevents
  a false 100% reading when the dongle is plugged in but the mouse is off.
- `capacity` is a percentage; `status` is `Charging`, `Discharging`, or
  `Unknown` (when offline); voltage is reported in mV by hardware and converted
  to uV in sysfs.

This is enough for the battery widget. No DPI, polling-rate, or profile
controls are implemented by the driver.

## 6. Settings control is still unproven

- The driver sends one known vendor report: a 17-byte output report
  `08 04 00 00 00 00 00 00 00 00 00 00 00 00 00 00 49` to request battery
  status. The reply is 17 bytes with capacity at index 6, charging flag at 7,
  and voltage at bytes 8-9. This proves a vendor HID interface exists, but says
  nothing about DPI or polling-rate commands.
- Search found no open-source Linux controller for the M600. The closest hits
  are for other mice (OpenMouse for VXE devices, Piper/Solaar for Logitech,
  Dragonize for Redragon). A Kysona mirror repo contains only Windows software
  and firmware archives, not protocol source.
- The vendor configuration path is a Windows utility. Reusing it from the
  shell is not a viable GUI.

## Update — dongle through dock/KVM

The user clarified that the `3554:F5D5` dongle is their mouse dongle. It is
plugged into a dock/hub that is part of a KVM switch sharing monitor, keyboard,
and mouse between this desktop and a Mac. The Nov 17 `F57D` event was the mouse
connected by USB-C for charging, directly to the PC.

Consequences:

- The battery device will disappear whenever the KVM is switched to the Mac.
  The widget must treat an absent device as a normal state, not an error.
- Bluetooth is not available on this machine. `bluetooth.service` is skipped
  because `/sys/class/bluetooth` does not exist, and `bluetoothctl` lists
  nothing. A Bluetooth battery path is out.

### The F5D5 dongle has the vendor report the driver uses

Report descriptor of interface 1 of the dongle (`hidraw2`), relevant part:

```
06 02 ff 09 02 a1 01 85 08 26 ff 00 75 08 95 10 09 02 81 00 09 02 91 00 c0
```

Decoded: vendor usage page `0xff02`, report ID `8`, 16 data bytes, with both
Input and Output reports. The kysona driver's battery request is exactly a
17-byte report: byte 0 is ID `8`, and the 16-byte payload starts with `0x04`
and ends with `0x49`. The reply is the same length, with capacity at index 6
and charging at index 7. So the protocol may work on this dongle. The only
known gap is that `F5D5` is missing from the driver's ID table.

A second vendor collection also exists: page `0xff04`, report ID `6`, 7-byte
Feature report. Its purpose is unknown.

The `0xff02:0x0002` collection is also the one used by the OpenMouse project
for other `3554` devices. That is a lead, not proof of M600 settings support.

## Decisions at this point (before the tests below)

- **Data source:** UPower/sysfs was the initial plan. It is superseded by the
  successful hidraw test later in this document.
- **Settings scope:** battery is feasible; settings need protocol work on the
  vendor HID interface. Plan a read-only panel as the fallback.
- **Currently plugged `F5D5` receiver:** has the right vendor report but no
  driver id. Two options were open at this point: adding the id dynamically to
  `kysona`, or talking to its hidraw node from user space. Neither had been
  attempted.

## Attempted driver bind — failed, restored

With user approval, a privileged test was run on the in-use dongle.

1. First `new_id` attempt with two values failed: `printf: write error:
   Invalid argument`. The Linux HID `new_id` format is `bus vendor product
   [driver_data]` in hex (checked in `new_id_store` in `hid-core.c`).
2. `printf "0003 3554 f5d5\n" > /sys/bus/hid/drivers/kysona/new_id` was
   accepted (the file's timestamp changed), though the `pkexec` wrapper was
   terminated with SIGTERM.
3. The mouse interface `0003:3554:F5D5.0003` was unbound from `hid-generic`.
   It then had no driver.
4. Binding it to `kysona` failed twice with `printf: write error: No such
   device`. No `kysona` error appeared in `journalctl -k`.
5. The device was restored to `hid-generic`. All five `hidraw` nodes are back on
   `hid-generic`, so mouse and keyboard input are unchanged.

Conclusion: dynamic binding of this dongle to the in-tree `kysona` driver does
not work on this kernel. It is not yet clear why. The user-space hidraw path is
the next option.

The dynamic ID `0003 3554 f5d5` remains in the running `kysona` driver; there is
no `remove_id` file for HID drivers here. It disappears on reboot and no
persistent udev or modprobe rule was added. All devices are back on their
original drivers.

## Successful user-space battery read

With user approval, a 17-byte vendor output report was written to the dongle's
vendor interface `/dev/hidraw2` (stable path
`/dev/input/by-id/usb-CX_2.4G_Wireless_Receiver-if01-hidraw`). This is the same
request the kysona driver sends.

Request:

```
08 04 00 00 00 00 00 00 00 00 00 00 00 00 00 00 49
```

Reply received within a few seconds, alongside ordinary 8-byte mouse reports:

```
08 04 00 00 00 02 1e 00 0e 71 00 00 00 00 00 00 aa
```

Decoded with the driver's layout:

- capacity (byte 6): `0x1e` = 30 percent
- charging flag (byte 7): `0x00`
- voltage (bytes 8-9): `0x0e71` = 3697 mV

So the in-use `F5D5` dongle does answer the battery query. A user-space reader
works without a kernel driver change. The reader must filter input reports by
ID `08` and length 17, because mouse movement reports arrive on the same node.

## Phase 0 conclusion and decisions

- **Battery data source (supersedes the earlier provisional decision):** a
  small user-space helper reading the vendor HID report from the dongle's
  hidraw node. UPower and sysfs are not usable for this dongle: no
  `power_supply` device is created, and a kernel-driver bind attempt failed.
- **Access:** add an udev `uaccess` rule for the dongle's hidraw node so the
  shell does not need root. The stable by-id path has two hidraw nodes; use the
  one named `-if01-hidraw`.
- **KVM behaviour:** when the KVM switches to the Mac, the dongle disappears
  from Linux. The widget must show an "unavailable" state, not a stale value.
- **Settings scope:** deferred. The vendor report channel is proven, but no
  DPI, polling-rate, or profile command is known. Phase 2 starts with a
  read-only panel unless a settings command is found by separate research.
  Guessing report bytes is out of scope for Phase 0.

## Remaining risk

- Report byte meanings beyond capacity/charging/voltage are unverified. The
  charging flag's `0x01` value has not been observed.
- The reader polls by writing a request; no change notification is known, so a
  modest interval (for example 30-60 seconds) is needed.
- Vendor reply format may differ on other M600 variants or dongles. v1 targets
  this machine only.

A decision on testing the in-use dongle. The test needs root and is reversible:

- Add `3554 F5D5` to the running driver with
  `echo "3554 f5d5" | sudo tee /sys/bus/hid/drivers/kysona/new_id`, or bind
  `0003:3554:F5D5.0003` through the driver's `bind` file.
- Replug or rescan, then check `/sys/class/power_supply/` and `upower -e`.
- Reversing it is done by unplugging the dongle; the dynamic id does not survive
  a reboot unless a persistent rule is added later.

If the battery report works, the normal wireless setup is solved and the KVM
case is handled by the widget's absent-device state. If it fails, the fallback
is a user-space hidraw reader with an udev `uaccess` rule, or a read-only panel
when the mouse is wired.

No privileged or device-write command has been run yet.

## Sources

- Kernel patch series "HID: add Kysona driver", Lode Willems, Oct 2024 —
  <https://lore.jethome.com/lkml/20241005120256.13847-4-me@lodewillems.com/T>
- Kysona M600 / Attack Shark X3 file mirror (Windows tools and firmware only) —
  <https://github.com/SLAzurin/attack-shark-x3-fix>
- Earlier Phoronix report on Linux 6.13 support —
  <https://www.phoronix.com/news/Linux-6.13-HID>
