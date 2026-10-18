#!/bin/sh
set -e

for var in DOMAIN_NAME FTP_USER FTP_PORT FTP_PASV_MIN FTP_PASV_MAX FTP_PASV_ADDRESS; do
    eval "value=\${$var}"
    [ -n "$value" ] || { echo "[ftp] error: $var is not set" >&2; exit 1; }
done

FTP_PASSWORD=$(cat /run/secrets/ftp_password)
[ -n "$FTP_PASSWORD" ] || { echo "[ftp] error: ftp_password secret is empty" >&2; exit 1; }

# FTP user with the same uid/gid as nobody, the owner of the WordPress files:
# uploads belong to nobody, so php-fpm can use them and the other way round
if ! id "$FTP_USER" > /dev/null 2>&1; then
    echo "[ftp] creating user ${FTP_USER}"
    useradd -o -u 65534 -g 65534 -d /var/www/html -M -s /sbin/nologin "$FTP_USER"
fi
# Set on every start, so a changed secret applies after a restart
echo "${FTP_USER}:${FTP_PASSWORD}" | chpasswd

# Self-signed certificate for FTPS (generated once per container)
if [ ! -f /etc/vsftpd/ssl/vsftpd.crt ]; then
    echo "[ftp] generating self-signed certificate for ${DOMAIN_NAME}"
    openssl req -x509 -nodes -newkey rsa:2048 -days 365 \
        -keyout /etc/vsftpd/ssl/vsftpd.key \
        -out /etc/vsftpd/ssl/vsftpd.crt \
        -subj "/O=42/CN=${DOMAIN_NAME}" 2>/dev/null
    chmod 600 /etc/vsftpd/ssl/vsftpd.key
fi

# Fill the template; only the listed variables are replaced
envsubst '${FTP_PORT} ${FTP_PASV_MIN} ${FTP_PASV_MAX} ${FTP_PASV_ADDRESS}' \
    < /etc/vsftpd/templates/vsftpd.conf.template \
    > /etc/vsftpd/vsftpd.conf

# Replace the shell so vsftpd becomes PID 1 and receives stop signals directly
exec vsftpd /etc/vsftpd/vsftpd.conf
