# Battery discovery notes

How we found a usable battery source for the Kysona M600 on this machine.
Date: 2026-11-18. Kernel `7.2.15-1-omarchy`, UPower 1.91.5.

## The question

Can Linux read the M600 battery through the dongle that is actually in use, and
can Quickshell read it without root?

## What the kernel offered

`hid_kysona` was loaded but had no device bound. Its IDs were `3554:F57C`,
`F57D`, `F58A`, and `F58C`. The plugged-in dongle is `3554:F5D5`, so it was
claimed by `hid-generic` and produced no `power_supply` device. `upower -e` only
showed `DisplayDevice`.

When the mouse was connected by USB-C it appeared as `3554:F57D` and the
`kysona` driver created a `power_supply` entry in sysfs with capacity, status,
and voltage. UPower still did not list it, so sysfs is the wired source.

## The dead end

We tried adding `F5D5` to the running driver with `new_id` and binding it to
`kysona`. The `new_id` format is `bus vendor product` in hex. The ID was added,
but binding failed with `No such device`. The device was restored to
`hid-generic` and all input kept working. No user-space code came from this.

## The path that worked

The `F5D5` report descriptor contains a vendor collection: page `0xff02`,
report ID `8`, 16 data bytes, with input and output reports. Sending the
driver's 17-byte battery request to the second hidraw interface gives a reply:

```
request  08 04 00 00 00 00 00 00 00 00 00 00 00 00 00 00 49
reply    08 04 00 00 00 02 1e 00 0e 71 00 00 00 00 00 00 aa
```

Byte 6 is the level, byte 7 is charging, bytes 8-9 are millivolts. Normal mouse
movement reports share the same node, so the reader filters on ID `8` and
length 17. A udev `uaccess` rule gives the shell access without root. Stable
path: `/dev/input/by-id/usb-CX_2.4G_Wireless_Receiver-if01-hidraw`.

## Things that changed the design

- The dongle sits behind a dock/KVM. It disappears when the KVM switches to the
  Mac, so the widget must show "unavailable" instead of a stale value.
- This machine has no Bluetooth adapter, so Bluetooth battery is out of scope
  here.
- Charging lifts the measured voltage. Both the firmware level and a voltage
  curve report higher while charging, then drop on unplug. The display uses
  OpenKysona's vendor voltage curve, a charging offset, grace periods, and a
  slew limiter.
- The mouse can be off while the dongle is present. Every poll must handle no
  reply as "unavailable".
- Settings need the same vendor report channel, but the kernel driver has no
  settings commands. That research moved to the roadmap.

## Sources

- Kysona HID driver patch — <https://lore.jethome.com/lkml/20241005120256.13847-4-me@lodewillems.com/T>
- OpenKysona protocol notes — <https://github.com/leoben49/OpenKysona/blob/main/docs/PROTOCOL.md>
- Linux 6.13 support report — <https://www.phoronix.com/news/Linux-6.13-HID>
