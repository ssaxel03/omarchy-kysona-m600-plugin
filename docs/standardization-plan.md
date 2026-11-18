# Standardization plan

Goal: make `axel.kysona-m600` installable and maintainable through Omarchy's
own plugin commands, with no symlinks and no manual file copying.

## What Omarchy actually requires

Read from `omarchy-plugin-add` and `omarchy-plugin-validate` on this machine:

- `omarchy plugin add <git-url>` clones the repo to a staging folder, runs
  `omarchy plugin validate` on the **repo root**, then moves it to
  `~/.config/omarchy/plugins/<id>/`.
- Therefore the repo root must contain `manifest.json` and every entry point.
  A nested `plugin/` folder fails with "missing manifest.json".
- The validator refuses **any symlink** inside the plugin folder (except `.git`).
  Our current symlink install would be rejected by a fresh `plugin add`.
- `id` must match `^[A-Za-z0-9][A-Za-z0-9._-]*$` and must not start with
  `omarchy.`. `axel.kysona-m600` is valid.
- `entryPoints.barWidget` is required for `kinds: ["bar-widget"]`.
- `barWidget.defaultSection` may be `left`, `centerBegin`, `center`,
  `centerEnd`, `tray`, or `right`. It controls placement when enabled without
  an explicit placement.
- `omarchy plugin add --enable` rescans plugins, enables the id, and places it
  using `defaultSection`.

Current deviations:

| Current state | Standard state |
| --- | --- |
| Plugin files live in `plugin/` | Plugin files at repo root |
| Installed as a symlink | Installed as a real git checkout by `omarchy plugin add` |
| No `barWidget.defaultSection` | `defaultSection: "right"` |
| Edits need `omarchy restart shell` | Code edits hot-reload from the plugins dir |
| Manual path placement | `omarchy plugin enable` / `omarchy bar put` |

## Steps

### 1. Flatten the repo into a plugin repo

- Move `manifest.json`, `Panel.qml`, `battery.py`, and `i18n/` from `plugin/`
  to the repo root.
- Delete the empty `plugin/` directory.
- `Qt.resolvedUrl("battery.py")` and `Qt.resolvedUrl("i18n")` keep working from
  the new root, so no QML path change is needed.
- Keep `docs/`, `udev/`, `README.md`, and `.gitignore` in the repo; the
  validator ignores extra files and only checks the manifest and entry points.

### 2. Update the manifest

Add to `barWidget`:

```json
"defaultSection": "right"
```

Keep `id`, `name`, `version`, `author`, `description`, `kinds`, and
`entryPoints` as they are.

### 3. Validate before publishing

```
omarchy plugin validate .
```

It must exit 0. Also check:

```
find . -name .git -prune -o -type l -print
```

This must print nothing.

Update README install instructions to describe `omarchy plugin add`, with the
udev rule as a separate prerequisite. Update docs links to the new paths.

### 4. Publish the repo

Push this repository to a git URL the user controls. The URL is required by
`omarchy plugin add`; this is the one decision needed from the user.

### 5. Replace the dev install with the standard install

```
rm ~/.config/omarchy/plugins/axel.kysona-m600
omarchy plugin add <git-url> --enable --yes
omarchy bar put axel.kysona-m600 --before omarchy.agents
```

`plugin add` clones real files, validates them, rescans the shell, enables the
plugin, and places it in `right` from `defaultSection`. The `bar put` step gives
the exact position beside the agents icon.

### 6. Install the udev rule

`omarchy plugin add` does not install system files. Keep this documented as a
prerequisite:

```
sudo install -m 644 udev/70-kysona-m600.rules /etc/udev/rules.d/70-kysona-m600.rules
sudo udevadm control --reload-rules
sudo udevadm trigger --subsystem-match=hidraw --action=add
```

The `70-` prefix is required because the uaccess builtin runs in
`73-seat-late.rules`.

### 7. Verify

```
omarchy plugin list | grep kysona
omarchy-shell shell listPlugins
python3 ~/.config/omarchy/plugins/axel.kysona-m600/battery.py
journalctl --user --no-pager -n 200 | grep -i kysona
```

Check the bar shows the mouse icon and percentage, clicking opens the panel,
and no QML errors appear. Confirm a saved edit hot-reloads without a shell
restart.

### 8. Day-to-day use after standardization

```
omarchy plugin update axel.kysona-m600     # pull changes
omarchy plugin disable axel.kysona-m600
omarchy plugin enable axel.kysona-m600 --section right
omarchy plugin remove axel.kysona-m600 --yes
```

## Notes / non-goals

- The udev rule stays a manual system step; plugins are not an install system
  for `/etc` files.
- Settings controls remain postponed in [roadmap.md](roadmap.md#phase-2--click-interaction-and-settings-panel-postponed).
- No version tag is created; the repo has no `VERSION` file and the plugin
  version lives in `manifest.json`.
