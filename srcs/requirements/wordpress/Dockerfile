FROM alpine:3.23

ARG WP_CLI_VERSION=2.12.0

# PHP 8.4 + php-fpm + the extensions WordPress needs, and wp-cli to install it
RUN apk add --no-cache \
        php84 php84-fpm php84-mysqli php84-phar php84-curl php84-mbstring \
        php84-openssl php84-xml php84-dom php84-zip php84-gd php84-iconv \
        php84-ctype php84-tokenizer php84-session php84-fileinfo php84-exif \
        php84-intl curl \
    && ln -sf /usr/bin/php84 /usr/bin/php \
    && curl -fsSL -o /usr/local/bin/wp \
        "https://github.com/wp-cli/wp-cli/releases/download/v${WP_CLI_VERSION}/wp-cli-${WP_CLI_VERSION}.phar" \
    && chmod +x /usr/local/bin/wp \
    && mkdir -p /var/www/html

COPY conf/www.conf /etc/php84/php-fpm.d/www.conf
COPY conf/php.ini /etc/php84/conf.d/zz-inception.ini
COPY tools/setup.sh /usr/local/bin/setup.sh
RUN chmod +x /usr/local/bin/setup.sh

ARG WP_PORT
EXPOSE ${WP_PORT}

WORKDIR /var/www/html

ENTRYPOINT ["/usr/local/bin/setup.sh"]
