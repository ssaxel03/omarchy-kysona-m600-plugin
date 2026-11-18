# Kysona M600 Quickshell module

An [Omarchy](https://omarchy.org/) shell plugin that shows the battery level of a
Kysona M600 wireless mouse in the bar. Clicking the widget opens a panel with the
mouse's current settings and controls for changing them.

**Status: battery widget implemented.** The bar widget and battery panel are
built and installed on this machine. Settings controls are not implemented; see
[docs/roadmap.md](docs/roadmap.md) and [Phase 0 findings](docs/phase-0-findings.md).

## Why a separate repo

Omarchy's bar, settings panel, and notifications run inside one long-lived
Quickshell process (`omarchy-shell`). User plugins live in
`~/.config/omarchy/plugins/<plugin-id>/` and hot-reload when their files change.
Bar placement is configured in `~/.config/omarchy/shell.json`.

Nothing under `/usr/share/omarchy/` is edited. That directory is package-owned
and gets overwritten on `omarchy update`. This repo holds the source; installing
means placing or linking it into the user plugin directory.

## What a plugin id is

A plugin id is just the unique name Omarchy uses to find the plugin. It is a
dot-separated string with no spaces. Built-in examples from your system:
`omarchy.monitor` (the display panel), `omarchy.audio`, `omarchy.bluetooth`.

The id appears in three places and they must match:

- the `id` field in the plugin's `manifest.json`;
- the plugin's folder name under `~/.config/omarchy/plugins/`;
- the `id` entry in `bar.layout` in `~/.config/omarchy/shell.json`, which is what
  puts the widget in the bar.

Third-party plugins use `<username>.<name>` so they cannot collide with
first-party `omarchy.*` ids. We will use `axel.kysona-m600`. It is a name, not a
file path, and you can change it before we write code.

## Feasibility at a glance

| Question | Current answer | Confidence |
| --- | --- | --- |
| Can Linux read the M600 battery? | Yes, tested on this machine. A 17-byte vendor HID report returns capacity, charging flag, and voltage from the in-use dongle. | Tested 2026-11-18; see [findings](docs/phase-0-findings.md). |
| Will UPower expose it to the shell? | No for the in-use `3554:F5D5` dongle. No `power_supply` device is created; the in-tree `kysona` driver only supports other USB IDs, and a dynamic bind test failed. The plugin reads hidraw directly. | Verified on this machine. |
| Can we change settings (DPI, polling rate, profiles)? | Unknown. The vendor report channel is proven, but no settings command is known. No open-source Linux controller for this mouse was found. | Main risk. Deferred to later research. |

Phase 0 was started on this machine. Findings and open checks are in
[docs/phase-0-findings.md](docs/phase-0-findings.md).

Sources checked while writing this:

- Phoronix: "Corsair Void Headset & Kysona M600 Lightweight Gaming Mouse Support In Linux 6.13" — <https://www.phoronix.com/news/Linux-6.13-HID>
- UPower device properties reference — <https://upower.freedesktop.org/docs/Device.html>
- Kysona M600 product page — <https://www.kysona.com/banner2-57137>

## Current behaviour

- **Bar widget:** a mouse icon plus the percentage on its right, inside one
  clickable button. It is always visible and sits immediately left of
  `omarchy.agents`. It polls every 10 seconds. `plugin/battery.py` first reads
  the `kysona` power_supply entry in sysfs (USB-C charging), then falls back to
  the 2.4 GHz receiver over hidraw (UPower does not expose that dongle). When the
  mouse is off or unreachable, the label switches to `—` and the panel shows
  "Unavailable". Charging adds a small bolt next to the percentage.
  The displayed percentage comes from a piecewise resting-voltage lookup. While
  charging, 80 mV is subtracted before the lookup to cancel the voltage lift; at
  4.20 V while wired it reports 100%. A 6-second grace period on plug-in and a
  1%-per-15s slew limiter suppress voltage spikes and jitter; unplugging uses a
  2-second grace period.
- **On click:** a Quickshell panel with the voltage-derived percentage, charge
  state, voltage, and device details. No settings
  controls yet.
- **UI model:** the built-in `omarchy.monitor` display panel in the top bar. Same
  pattern: a `bar-widget` plugin with a `Panel.qml` that uses `qs.Ui` `Panel` and
  supports keyboard navigation. Its source at
  `/usr/share/omarchy/shell/plugins/panels/monitor/Panel.qml` is our read-only
  reference.
- **Fallback:** if settings writes are not feasible, the panel still shows device
  status and links to the vendor configuration path rather than pretending to
  control it.

## Omarchy conventions this must follow

- Build on `qs.Ui` components (`KeyboardPanel` / `PopupCard`, `Button`) rather than
  custom open/close animation, so theme, motion, and RTL mirroring come for free.
- Use `qs.Commons` `Style` for colors and `Style.duration()` / `Style.easeOut` for
  any animation that is needed. No hardcoded theme colors, no bare durations.
- Set `textFormat: Text.PlainText` on all text bound to device or external data.
- Ship strings in `i18n/` catalogs read through `Commons.Translations`; display
  numbers with `Commons.I18n.formatNumber`.
- Keep network access out of the plugin. Validate any device data before display.

## Device

- Target mouse: Kysona M600 (confirmed).
- Connectivity: 2.4 GHz USB dongle, Bluetooth, and wired USB-C (per Kysona's
  product materials).
- Battery: rechargeable Li-poly, claimed around 80 hours per charge (per Kysona).
- Exact sensor, DPI ranges, and battery capacity differ between M600 variants and
  firmware batches. Confirm against the physical device before relying on them.

## Install

These steps are done on this machine.

1. Install `udev/70-kysona-m600.rules` into `/etc/udev/rules.d/` and reload udev.
   The `70-` prefix matters: the `uaccess` builtin runs in `73-seat-late.rules`,
   so a later rule would be too late to get an access ACL.
2. Link this repo's `plugin/` directory into
   `~/.config/omarchy/plugins/axel.kysona-m600/`.
3. Add `{"id": "axel.kysona-m600"}` to `bar.layout.right` in
   `~/.config/omarchy/shell.json`, before `omarchy.agents`. `omarchy bar put
   axel.kysona-m600 --before omarchy.agents` does this.
4. Because the plugin directory is a symlink to this repo, file-watch hot reload
   does not fire. After edits, run `omarchy restart shell`.

Check with `omarchy plugin list | grep kysona` and with `python3 plugin/battery.py`
from this repo. The helper prints a JSON line with `available`, `percentage`,
`charging`, and `voltage`.

## Non-goals

- Replacing the vendor's firmware update or button-remapping utility.
- Supporting other mice in v1. The widget is built for one known device, with an
  explicit "unknown device" state if it is unplugged.
- Running background network requests or telemetry.
