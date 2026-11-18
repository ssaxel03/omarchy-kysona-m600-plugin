#!/bin/sh
# Copy VERSION into manifest.json. VERSION is the only value to edit.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
VERSION=$(tr -d '\n' < "$ROOT/VERSION")

case "$VERSION" in
  [0-9]*.[0-9]*.[0-9]*) ;;
  *) echo "VERSION must be MAJOR.MINOR.PATCH, got '$VERSION'" >&2; exit 1 ;;
esac

jq --arg version "$VERSION" '.version = $version' "$ROOT/manifest.json" > "$ROOT/manifest.json.tmp"
mv "$ROOT/manifest.json.tmp" "$ROOT/manifest.json"
echo "manifest.json version set to $VERSION"
