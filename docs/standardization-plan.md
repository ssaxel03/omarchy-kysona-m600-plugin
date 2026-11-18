# Installation notes

How Omarchy plugin installation works and how this plugin is installed now.
Completed on 2026-11-18.

## What we learned

Reading `omarchy-plugin-add` and `omarchy-plugin-validate` on this machine:

- `omarchy plugin add <git-url>` clones the repo to a staging folder, validates
  the **repo root**, then moves it to `~/.config/omarchy/plugins/<id>/`.
- The repo root must contain `manifest.json` and the entry points. A nested
  `plugin/` folder fails validation.
- Symlinks inside the plugin folder are rejected, except `.git`.
- `id` must match `^[A-Za-z0-9][A-Za-z0-9._-]*$` and cannot use the `omarchy.`
  prefix. `ssaxel03.kysona-m600` is valid.
- `kinds: ["bar-widget"]` requires `entryPoints.barWidget`.
- `barWidget.defaultSection` chooses the section when no placement is given;
  this plugin uses `right`.
- `--enable` rescans plugins, enables the id, and places it using that section.

## Current state

- Repo root is the plugin folder: `manifest.json`, `Panel.qml`, `battery.py`,
  `i18n/`, plus `docs/`, `udev/`, and `scripts/`.
- Pushed to `https://github.com/ssaxel03/omarchy-kysona-m600-plugin.git`.
- Installed with:
  ```
  omarchy plugin add https://github.com/ssaxel03/omarchy-kysona-m600-plugin.git --enable --yes
  omarchy bar put ssaxel03.kysona-m600 --before omarchy.agents
  ```
- The installed plugin is a real git checkout, not a symlink. Edits hot-reload
  from the plugins dir.

`omarchy plugin add` does not install system files. The udev rule is a separate
one-time step:

```
~/.config/omarchy/plugins/ssaxel03.kysona-m600/scripts/install-udev.sh
```

Wired USB-C mode works without it. Wireless mode needs it, and the panel shows
"udev rule missing" when access is blocked. The `70-` prefix matters because
the uaccess builtin runs in `73-seat-late.rules`.

## Verify

```
omarchy plugin list | grep kysona
omarchy plugin validate ~/.config/omarchy/plugins/ssaxel03.kysona-m600
python3 ~/.config/omarchy/plugins/ssaxel03.kysona-m600/battery.py
```

The helper prints one JSON line. The bar should show the mouse icon and
percentage beside the agents icon.

## Day to day

```
omarchy plugin update ssaxel03.kysona-m600
omarchy plugin disable ssaxel03.kysona-m600
omarchy plugin enable ssaxel03.kysona-m600 --section right
omarchy plugin remove ssaxel03.kysona-m600 --yes
```

Local repo edits reach the installed plugin only after a push and
`omarchy plugin update ssaxel03.kysona-m600`.
