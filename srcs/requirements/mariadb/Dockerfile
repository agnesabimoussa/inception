FROM alpine:3.23

RUN apk add --no-cache mariadb mariadb-client \
    && mkdir -p /run/mysqld /var/lib/mysql \
    && chown -R mysql:mysql /run/mysqld /var/lib/mysql

COPY conf/zz-inception.cnf /etc/my.cnf.d/zz-inception.cnf
COPY tools/init.sh /usr/local/bin/init.sh
# MariaDB ignores world-writable config files: force safe permissions
RUN chmod 644 /etc/my.cnf.d/zz-inception.cnf \
    && chmod +x /usr/local/bin/init.sh

ARG MYSQL_PORT
EXPOSE ${MYSQL_PORT}

ENTRYPOINT ["/usr/local/bin/init.sh"]
