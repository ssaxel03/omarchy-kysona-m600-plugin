#!/bin/sh
# Grant the active desktop user access to the Kysona 2.4 GHz receiver.
# Only needed for wireless mode; wired USB-C battery works without this.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
RULE="$ROOT/udev/70-kysona-m600.rules"

[ -f "$RULE" ] || { echo "missing $RULE" >&2; exit 1; }

sudo install -m 644 "$RULE" /etc/udev/rules.d/70-kysona-m600.rules
sudo udevadm control --reload-rules
sudo udevadm trigger --subsystem-match=hidraw --action=add

echo "udev rule installed. If the wireless battery still shows unavailable, replug the dongle."
