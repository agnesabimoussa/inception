#!/bin/sh
set -e

for var in DOMAIN_NAME NGINX_PORT WP_HOST WP_PORT; do
    eval "value=\${$var}"
    [ -n "$value" ] || { echo "[nginx] error: $var is not set" >&2; exit 1; }
done

# Self-signed certificate for the domain (generated once per container)
if [ ! -f /etc/nginx/ssl/inception.crt ]; then
    echo "[nginx] generating self-signed certificate for ${DOMAIN_NAME}"
    openssl req -x509 -nodes -newkey rsa:2048 -days 365 \
        -keyout /etc/nginx/ssl/inception.key \
        -out /etc/nginx/ssl/inception.crt \
        -subj "/O=42/CN=${DOMAIN_NAME}" 2>/dev/null
fi

# Fill the template; only the listed variables are replaced
envsubst '${DOMAIN_NAME} ${NGINX_PORT} ${WP_HOST} ${WP_PORT}' \
    < /etc/nginx/templates/inception.conf.template \
    > /etc/nginx/http.d/inception.conf

# Replace the shell so nginx becomes PID 1; daemon off keeps it in the foreground
exec nginx -g 'daemon off;'
