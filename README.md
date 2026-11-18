# Omarchy Kysona M600 Plugin

An Omarchy plugin for the Kysona M600 mouse. It currently provides a bar module
that shows battery level next to the agents icon: a mouse icon, the percentage,
and a charging bolt when plugged in. Click it for charge state, voltage, and
connection details.

Battery works with the **USB-C cable** and the **2.4 GHz dongle**. The percentage
is estimated from the mouse's voltage.

Settings controls (DPI, polling rate, sensor options, button mapping) are on the
roadmap. See [Settings roadmap](#settings-roadmap).

## Install

Requires Omarchy with Quickshell.

```sh
omarchy plugin add https://github.com/ssaxel03/omarchy-kysona-m600-plugin.git --enable --yes
omarchy bar put ssaxel03.kysona-m600 --before omarchy.agents
```

### USB-C (wired)

That is all. Plug the mouse in with USB-C. The bar shows the battery level and
a charging bolt. No other setup is needed.

### 2.4 GHz dongle

Linux only lets root read the dongle directly. Grant your user access once:

```sh
~/.config/omarchy/plugins/ssaxel03.kysona-m600/scripts/install-udev.sh
```

It installs `/etc/udev/rules.d/70-kysona-m600.rules` and asks for your password.
Replug the dongle if it was already connected. If access is missing, the panel
says "udev rule missing".

### Bluetooth

Not supported. The M600 exposes Bluetooth battery through the standard GATT
Battery Service, which this plugin does not read. Contributions are welcome.

## Settings roadmap

The panel is read-only today. DPI, polling rate, sensor options, and button
mapping are planned. The M600 V2 protocol is documented by
[OpenKysona](https://github.com/leoben49/OpenKysona), including the flash
registers and read/write commands used by their browser-based configuration
tool. See [docs/roadmap.md](docs/roadmap.md#phase-2--click-interaction-and-settings-panel-postponed)
for the scope.

Contributions for settings support, Bluetooth, or anything else are welcome.

## Manage

```sh
omarchy plugin update ssaxel03.kysona-m600
omarchy plugin disable ssaxel03.kysona-m600
omarchy plugin enable ssaxel03.kysona-m600 --section right
omarchy plugin remove ssaxel03.kysona-m600 --yes
```

## Versioning

`VERSION` at the repo root is the source of truth. To release:

```sh
# edit VERSION to MAJOR.MINOR.PATCH
scripts/sync-version.sh
git add -A && git commit -m "Release X.Y.Z" && git push
omarchy plugin update ssaxel03.kysona-m600
```
