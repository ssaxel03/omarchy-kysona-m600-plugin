# Roadmap

Goal: an Omarchy Quickshell plugin that shows the Kysona M600 mouse battery in
the bar and opens a settings panel on click, following Omarchy theme and plugin
guidelines.

This document is the working plan. Phases are ordered by dependency; Phase 0 is
a gate, not a formality. The whole settings feature depends on what we learn
there.

## Phase 0 — Feasibility and discovery (gate)

No UI code until these answers exist.

1. **Confirm kernel support on this machine.**
   - Check kernel version and that the `kysona` HID driver is present/loaded.
   - Plug in the mouse via its 2.4 GHz dongle, Bluetooth, and USB-C in turn;
     note which mode exposes the device.
   - Look for a battery device under `/sys/class/power_supply/` and read its
     `capacity`, `status`, and ` BatteryLevel`-style fields.
   - Record: does battery percentage actually update as the mouse discharges?

2. **Confirm the data path to Quickshell.**
   - Run `upower -e` and `upower -i <device-path>` for the mouse.
   - Decide: read UPower over D-Bus, or read sysfs directly. Prefer UPower for
     change signals; use sysfs as fallback.
   - Note the exact device id / sysfs path so the widget can find the mouse
     without matching on a fragile name.

3. **Investigate settings control.**
   - List `/dev/hidraw*` before and after plugging in the mouse; inspect the
     report descriptor and any feature reports.
   - Search for an existing open-source M600 controller before writing one.
   - Determine whether DPI, polling rate, and profiles are writable, and what
     privileges are needed (likely a udev rule for hidraw access).
   - If writes are not feasible, decide the fallback scope now: read-only status
     panel, or a panel that points to the vendor utility.

4. **Fix scope.** Write down the exact settings in v1 (candidates: DPI preset,
   polling rate, profile switch). Everything not proven here moves to "later".

**Exit criteria:** a short note in `docs/` with commands run, observed output,
and the chosen data source and settings scope.

## Phase 1 — Minimal battery widget

1. Create the plugin skeleton in `~/.config/omarchy/plugins/axel.kysona-m600/`
   (or develop here and link it in during testing).
2. Implement a battery data source:
   - Subscribe to UPower property changes; expose `percentage`, `state`, and
     `available` to QML.
   - Handle "device unplugged" as an explicit state, not as 0% or 100%.
3. Build the bar widget with `qs.Ui` components:
   - battery icon + percentage, `textFormat: Text.PlainText`;
   - colors from the active theme via `qs.Commons` `Style`, no hardcoded values;
   - tooltip via the Omarchy-provided component only after the plain-text safety
     check.
4. Add the plugin id to `bar.layout` in `~/.config/omarchy/shell.json`. Put it in
   `centerEnd` or `right` so the clock stays centered.
5. Verify hot reload with saved edits and, if needed, `omarchy-shell shell rescanPlugins`.

**Exit criteria:** percentage in the bar tracks `upower -i`, survives a shell
restart, and follows theme changes.

## Phase 2 — Click interaction and settings panel

1. Copy the structure of the built-in `omarchy.monitor` display panel, which is
   the GUI target the user asked for. It is a `bar-widget` plugin: `manifest.json`
   declares id `omarchy.monitor` and entry point `panels/monitor/Panel.qml`; the
   QML uses `qs.Ui` `Panel` with `moduleName` and `ipcTarget`, plus a keyboard
   cursor model so `j`/`k` and pointer hover share one highlight. Our plugin uses
   the same shape with id `axel.kysona-m600`. Read-only reference:
   `/usr/share/omarchy/shell/plugins/panels/monitor/Panel.qml`.
2. Use `KeyboardPanel` growing from the bar icon (or `PopupCard` where a bar
   panel is not available), so motion, focus, and RTL mirroring are inherited
   from Omarchy's kit.
3. Panel content:
   - battery detail (percentage, charging state, last updated);
   - controls for only the settings proven writable in Phase 0;
   - clear disabled / "not supported" states instead of dead controls.
4. Implement the settings writer behind a small helper if hidraw is involved:
   - keep device access out of the QML layer;
   - add a udev rule for the minimum required access;
   - validate every value before writing, never interpolate untrusted input into
     a command.
5. Persist chosen settings locally, or read current values back from the device
   on open so the panel never lies about device state.

**Exit criteria:** opening the panel shows live values; a change is confirmed by
reading the value back or by an observable device response.

## Phase 3 — Omarchy compliance and polish

- **Theme:** verify all colors come from theme values, including panel background
  and badges. Test with at least two themes.
- **Motion:** only `Style.duration()` durations, `Style.easeOut` or OutCubic,
  under 300 ms, exits shorter than entrances, no scale from 0. Confirm with
  `omarchy toggle animations` off.
- **Translations:** add `i18n/en.json` via `Commons.Translations`; keep strings
  whole with `%1` placeholders; use `Commons.I18n.formatNumber` for percentages.
- **Layout:** confirm RTL through `LayoutMirroring.enabled` / `KeyboardPanel`;
  no hardcoded `x` positioning.
- **Safety:** audit every dynamic text sink for `Text.PlainText`; add a regression
  case with markup-shaped input; keep the plugin network-free.
- **Low battery:** optional notification using Omarchy's notification path,
  with a configurable threshold and an off switch.

**Exit criteria:** a checklist pass against Omarchy's plugin UI safety, motion,
and translations guidance, with findings recorded in `docs/`.

## Phase 4 — Packaging and handover

- Decide distribution: plain git repo cloned into the plugins directory, or
  `omarchy plugin clone <url>` if that flow fits a third-party plugin. Verify
  which one works; do not assume.
- Finalize the plugin id and document exact install / uninstall steps in README.
- Add a screenshot and a short settings reference.
- Document how to update when the kernel driver or Omarchy shell changes.

## Non-goals

- Firmware updates, full button remapping, or macro profiles.
- Supporting multiple mouse models in v1.
- Background network access or telemetry.

## Open questions

- Does the M600 expose battery in Bluetooth mode as well as 2.4 GHz?
- Is there already a usable open-source M600 settings tool?
- Which settings does the Linux `kysona` driver expose, if any?
- Where will the repo be hosted? The plugin id is set: `axel.kysona-m600`.

## Definition of done

- Widget shows a correct, live battery percentage in the bar.
- Click opens a themed panel with at least one working settings control, or a
  clearly documented fallback if none is writable.
- Plugin survives Omarchy updates and theme changes, hot-reloads on edit, and
  passes the Phase 3 checklist.
- README contains accurate install steps verified on this machine.
