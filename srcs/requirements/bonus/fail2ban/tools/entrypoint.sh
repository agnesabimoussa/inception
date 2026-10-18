#!/bin/sh
set -e

# fail2ban refuses to start a jail whose log file does not exist yet
touch /var/log/inception/access.log

# Replace the shell so fail2ban becomes PID 1; -f keeps it in the foreground,
# -x removes a socket left behind by a crash
exec fail2ban-server -f -x
