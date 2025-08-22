#!/usr/bin/env bash
set -euo pipefail

# Map UID/GID at runtime if overridden
if [[ -n "${PUID:-}" && -n "${PGID:-}" ]]; then
  if getent group "${PGID}" >/dev/null 2>&1; then groupmod -o -g "${PGID}" app; else groupmod -o -g "${PGID}" app; fi
  usermod -o -u "${PUID}" app
fi

# Ensure ownership and umask
chown -R app:app /config /downloads
umask "${UMASK:-002}"

# Seed config if missing
if [[ ! -f /config/nzbget.conf ]]; then
  cp /defaults/nzbget.conf /config/nzbget.conf
  chown app:app /config/nzbget.conf
fi

# Apply TZ
if [[ -n "${TZ:-}" ]]; then
  ln -snf "/usr/share/zoneinfo/${TZ}" /etc/localtime && echo "${TZ}" > /etc/timezone || true
fi

# Exec as non-root
exec gosu app:app "$@"
