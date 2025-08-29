#!/usr/bin/env bash
set -euo pipefail

# Helpers
ensure_dir() {
  local d="$1"
  if [[ ! -d "$d" ]]; then
    mkdir -p "$d" || true
  fi
  # Best-effort cooperative perms: 775 + setgid for group inheritance
  chmod 2775 "$d" || true
  chown app:app "$d" || true
}

# Map UID/GID (best-effort, only if different)
if [[ -n "${PGID:-}" ]]; then
  if [[ "$(getent group app | awk -F: '{print $3}')" != "${PGID}" ]]; then
    groupmod -o -g "${PGID}" app || true
  fi
fi
if [[ -n "${PUID:-}" ]]; then
  if [[ "$(id -u app)" != "${PUID}" ]]; then
    usermod -o -u "${PUID}" app || true
  fi
fi

# UMASK: validate, default to 002
UMASK_VAL="${UMASK:-002}"
if [[ ! "$UMASK_VAL" =~ ^0?[0-7]{3}$ ]]; then
  UMASK_VAL="002"
fi
umask "$UMASK_VAL"

# Ensure key dirs exist with cooperative perms
ensure_dir /config
ensure_dir /downloads

# Light-touch ownership on dirs only (avoid -R; safer on NFS)
chown app:app /config    || true
chown app:app /downloads || true

# Seed runtime config if missing; secure perms (660) and cooperative group
if [[ ! -f /config/nzbget.conf && -w /config ]]; then
  # install: mode 660, owner:group app:app
  install -m 660 -o app -g app /defaults/nzbget.conf /config/nzbget.conf || true
elif [[ -f /config/nzbget.conf ]]; then
  # Make it group-writable and owned by app:app (best-effort)
  chgrp app /config/nzbget.conf || true
  chmod 660 /config/nzbget.conf || true
fi

# Optional: default ACLs for group inheritance (if setfacl present)
if command -v setfacl >/dev/null 2>&1; then
  setfacl -m g:app:rwx -m d:g:app:rwx /config 2>/dev/null || true
  setfacl -m g:app:rwx -m d:g:app:rwx /downloads 2>/dev/null || true
fi

# Best-effort TZ
if [[ -n "${TZ:-}" ]]; then
  ln -snf "/usr/share/zoneinfo/${TZ}" /etc/localtime && echo "${TZ}" >/etc/timezone || true
fi

# Run as non-root
exec gosu app:app "$@"
