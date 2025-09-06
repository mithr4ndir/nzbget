#!/usr/bin/env bash
set -euo pipefail

CONFIG_DIR="${CONFIG_DIR:-/config}"
DEFAULTS_DIR="${DEFAULTS_DIR:-/defaults}"
TARGET="${TARGET:-$CONFIG_DIR/nzbget.conf}"
SRC="${SRC:-$DEFAULTS_DIR/nzbget.conf}"

mkdir -p "$CONFIG_DIR"

# copy only if it doesn't exist (or is empty)
if [ ! -s "$TARGET" ]; then
  # temp+mv avoids partial writes on NFS
  tmp="$(mktemp "$CONFIG_DIR/.init.XXXXXX")"
  cp "$SRC" "$tmp"
  mv -f "$tmp" "$TARGET"
fi

exec "$@"
