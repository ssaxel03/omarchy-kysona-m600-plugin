# Roadmap

The plugin is an Omarchy Quickshell plugin for the Kysona M600 mouse. Battery
display is done. Everything below is what could be built next.

## Now

- Bar module with mouse icon and percentage, beside `omarchy.agents`.
- Click opens a read-only panel with charge state, voltage, and connection.
- Wired battery comes from sysfs; 2.4 GHz battery comes from hidraw.
- Voltage-based estimate with charging compensation and smoothing.

The discovery process is in [phase-0-findings.md](phase-0-findings.md). The
install path is in [standardization-plan.md](standardization-plan.md).

## Phase 2 — Click interaction and settings panel (postponed)

Postponed on request. The goal is a panel in the style of Omarchy's
`omarchy.monitor` that reads and writes mouse settings.

[OpenKysona](https://github.com/leoben49/OpenKysona) already documents the
protocol. Its `docs/PROTOCOL.md` lists the flash registers: polling rate at
`0x00`, DPI stage count at `0x02`, active stage at `0x04`, DPI stages at `0x0C`,
plus sensor toggles and button bindings. Reads and writes use commands `0x08`
and `0x07` over the same vendor HID report the battery reader uses.

Work to do:

1. Extend `battery.py` (or add a sibling helper) with read/write commands and
   checksums from OpenKysona's `src/lib/protocol/`.
2. Show current values in the panel: DPI stages, polling rate, sensor options,
   button bindings.
3. Use `qs.Ui` `KeyboardPanel` so theme, motion, focus, and RTL mirroring come
   from Omarchy.
4. Write values through the helper, then read them back to confirm.
5. Keep device access out of QML and validate every value before writing.

## Other ideas

- **Bluetooth:** read battery from the GATT Battery Service if a Bluetooth
  adapter or paired device is available.
- **Polish:** check theme, motion, translations, and `Text.PlainText` across the
  panel; add a low-battery notification with a configurable threshold.
- **Packaging:** add a screenshot and a short settings reference to the README
  when settings land.
- **More devices:** support other Kysona mice on the same Compx platform after
  testing their USB IDs.
