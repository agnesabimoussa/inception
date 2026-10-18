#!/bin/sh
set -e

[ -n "${STATIC_PORT}" ] || { echo "[static] error: STATIC_PORT is not set" >&2; exit 1; }

# Replace the shell so httpd becomes PID 1; -f keeps it in the foreground,
# -v logs each request to docker logs
exec busybox-extras httpd -f -v -p "${STATIC_PORT}" -h /var/www/static
