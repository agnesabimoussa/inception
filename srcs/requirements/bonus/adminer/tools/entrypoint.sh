#!/bin/sh
set -e

[ -n "${ADMINER_PORT}" ] || { echo "[adminer] error: ADMINER_PORT is not set" >&2; exit 1; }

# Replace the shell so php-fpm becomes PID 1; -F keeps it in the foreground
exec php-fpm84 -F
