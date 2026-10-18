FROM alpine:3.23

RUN apk add --no-cache redis \
    && mkdir -p /run/redis \
    && chown redis:redis /run/redis

COPY conf/redis.conf /etc/redis/inception.conf
COPY tools/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod 644 /etc/redis/inception.conf \
    && chmod +x /usr/local/bin/entrypoint.sh

ARG REDIS_PORT
EXPOSE ${REDIS_PORT}

# Redis does not need root; Docker secrets are readable by any user
USER redis

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
