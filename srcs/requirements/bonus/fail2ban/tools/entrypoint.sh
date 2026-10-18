#!/bin/sh
set -e

# nginx creates the log in the shared volume (read-only here). fail2ban refuses
# to start a jail without its log, so exit and let the restart policy retry.
[ -f /var/log/inception/access.log ] || {
    echo "[fail2ban] waiting for nginx to create /var/log/inception/access.log" >&2
    exit 1
}

# Replace the shell so fail2ban becomes PID 1; -f keeps it in the foreground,
# -x removes a socket left behind by a crash
exec fail2ban-server -f -x
