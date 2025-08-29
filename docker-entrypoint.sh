#!/usr/bin/env bash
set -euo pipefail

# Map UID/GID (best-effort)
if [[ -n "${PUID:-}" || -n "${PGID:-}" ]]; then
  [[ -n "${PGID:-}" ]] && groupmod -o -g "${PGID}" app || true
  [[ -n "${PUID:-}" ]] && usermod  -o -u "${PUID}" app || true
fi

# Cooperative permissions
umask "${UMASK:-002}"

# Best-effort ownership (don’t fail on NFS root_squash)
[[ -w /config    ]] && chown -R app:app /config    || true
[[ -w /downloads ]] && chown -R app:app /downloads || true

# Seed runtime config if missing; create as app:app so it's writable on NFS
if [[ ! -f /config/nzbget.conf && -w /config ]]; then
  gosu app:app sh -lc 'cp /defaults/nzbget.conf /config/nzbget.conf && chmod 664 /config/nzbget.conf'
elif [[ -f /config/nzbget.conf ]]; then
  # ensure writable by group (cooperate with other *arr apps)
  chmod g+w /config/nzbget.conf || true
fi

# Best-effort TZ
if [[ -n "${TZ:-}" ]]; then
  ln -snf "/usr/share/zoneinfo/${TZ}" /etc/localtime && echo "${TZ}" >/etc/timezone || true
fi

# Run as non-root
exec gosu app:app "$@"
