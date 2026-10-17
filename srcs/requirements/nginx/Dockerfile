FROM alpine:3.23

# nginx, openssl for the self-signed certificate, envsubst to fill the config template
RUN apk add --no-cache nginx openssl gettext-envsubst \
    && rm -f /etc/nginx/http.d/default.conf \
    && mkdir -p /etc/nginx/ssl /etc/nginx/templates /var/www/html \
    && ln -sf /dev/stdout /var/log/nginx/access.log \
    && ln -sf /dev/stderr /var/log/nginx/error.log

COPY conf/inception.conf.template /etc/nginx/templates/inception.conf.template
COPY tools/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ARG NGINX_PORT
EXPOSE ${NGINX_PORT}

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
