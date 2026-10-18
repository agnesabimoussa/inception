FROM alpine:3.23

# BusyBox httpd (shipped in busybox-extras on Alpine): a tiny static file server
RUN apk add --no-cache busybox-extras

COPY site/ /var/www/static/
COPY tools/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ARG STATIC_PORT
EXPOSE ${STATIC_PORT}

# Serving files on a port above 1024 does not need root
USER nobody

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
