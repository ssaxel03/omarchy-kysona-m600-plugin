# Kysona M600 Quickshell module

An [Omarchy](https://omarchy.org/) shell plugin that shows the battery level of a
Kysona M600 wireless mouse in the bar. Clicking the widget opens a panel with the
mouse's current settings and controls for changing them.

**Status: planning / feasibility.** This repo contains documentation only. No
plugin code exists yet. The plan is in [docs/roadmap.md](docs/roadmap.md).

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
| Can Linux read the M600 battery? | Yes, in principle. Linux 6.13 added a `kysona` HID driver that reports battery status for the M600. | Reported by Phoronix, 20 Nov 2024. Verify on this machine. |
| Will UPower expose it to the shell? | Likely, through `/sys/class/power_supply/` and `upower`, as with other HID mice. | To verify. Check which field carries the percentage. |
| Can we change settings (DPI, polling rate, profiles)? | Unknown. The vendor utility normally does this. The kernel driver is not known to expose settings. May need hidraw protocol work or an existing open-source controller. | Main risk. Investigate before committing. |

Sources checked while writing this:

- Phoronix: "Corsair Void Headset & Kysona M600 Lightweight Gaming Mouse Support In Linux 6.13" — <https://www.phoronix.com/news/Linux-6.13-HID>
- UPower device properties reference — <https://upower.freedesktop.org/docs/Device.html>
- Kysona M600 product page — <https://www.kysona.com/banner2-57137>

## Planned behaviour

- **Bar widget:** battery icon plus percentage, using the active Omarchy theme
  colors. Updates on change, not on a fixed poll loop where avoidable.
- **On click:** a Quickshell panel showing battery detail and the settings we can
  actually control. The exact controls depend on Phase 0 of the roadmap.
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

## Install (planned, not implemented)

1. Put or link the plugin source into `~/.config/omarchy/plugins/axel.kysona-m600/`.
2. Add the id `axel.kysona-m600` to `bar.layout` in `~/.config/omarchy/shell.json`
   (a section such as `centerEnd` or `right` keeps the clock centered).
3. Changes hot-reload. If they do not, run `omarchy-shell shell rescanPlugins`.

## Non-goals

- Replacing the vendor's firmware update or button-remapping utility.
- Supporting other mice in v1. The widget is built for one known device, with an
  explicit "unknown device" state if it is unplugged.
- Running background network requests or telemetry.
