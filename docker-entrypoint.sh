#!/usr/bin/env bash
set -euo pipefail

# Map UID/GID at runtime if provided (non-fatal if it fails)
if [[ -n "${PUID:-}" || -n "${PGID:-}" ]]; then
  [[ -n "${PGID:-}" ]] && groupmod -o -g "${PGID}" app || true
  [[ -n "${PUID:-}" ]] && usermod  -o -u "${PUID}" app || true
fi

# Ensure umask early
umask "${UMASK:-002}"

# Best-effort ownership fixes (skip on NFS root_squash)
if [[ -w /config ]]; then
  chown -R app:app /config || true
fi
if [[ -w /downloads ]]; then
  chown -R app:app /downloads || true
fi

# Seed config only if target is writable and file missing
if [[ ! -f /config/nzbget.conf ]]; then
  if [[ -w /config ]]; then
    cp /defaults/nzbget.conf /config/nzbget.conf || true
    chown app:app /config/nzbget.conf || true
  else
    echo "WARN: /config not writable; skipping seed. Provide /config/nzbget.conf via PVC/volume."
  fi
fi

# Apply TZ (best-effort)
if [[ -n "${TZ:-}" ]]; then
  ln -snf "/usr/share/zoneinfo/${TZ}" /etc/localtime && echo "${TZ}" > /etc/timezone || true
fi

# Drop to app user
exec gosu app:app "$@"
