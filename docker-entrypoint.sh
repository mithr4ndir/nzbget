#!/usr/bin/env bash
set -euo pipefail

# Do not mutate users, groups, perms, or /etc at runtime.
# Do not seed or edit /config at runtime.

exec "$@"
