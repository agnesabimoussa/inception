FROM alpine:3.23

ARG ADMINER_VERSION=6.1.2

# PHP 8.4 + php-fpm + the extensions Adminer needs for MySQL/MariaDB.
# curl is only needed to download Adminer, so it is removed afterwards.
RUN apk add --no-cache \
        php84 php84-fpm php84-mysqli php84-session php84-mbstring \
    && apk add --no-cache --virtual .fetch curl \
    && mkdir -p /var/www/adminer \
    && curl -fsSL -o /var/www/adminer/index.php \
        "https://github.com/vrana/adminer/releases/download/v${ADMINER_VERSION}/adminer-${ADMINER_VERSION}-mysql.php" \
    && apk del .fetch

COPY conf/www.conf /etc/php84/php-fpm.d/www.conf
COPY tools/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ARG ADMINER_PORT
EXPOSE ${ADMINER_PORT}

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
