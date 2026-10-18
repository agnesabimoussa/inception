#!/bin/sh
set -e

: "${REDIS_PORT:?REDIS_PORT is not set}"

REDIS_PASSWORD=$(cat /run/secrets/redis_password)
[ -n "$REDIS_PASSWORD" ] || { echo "[redis] error: redis_password secret is empty" >&2; exit 1; }

# The password goes in a private file instead of the command line (visible in ps)
umask 077
echo "requirepass ${REDIS_PASSWORD}" > /run/redis/auth.conf

# Replace the shell so redis-server becomes PID 1 and receives stop signals directly
exec redis-server /etc/redis/inception.conf --port "${REDIS_PORT}"
