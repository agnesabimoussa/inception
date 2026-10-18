FROM alpine:3.23

# Remove Alpine's default sshd jail: there is no ssh log in this container
RUN apk add --no-cache fail2ban \
    && rm -f /etc/fail2ban/jail.d/* \
    && mkdir -p /var/log/inception /var/lib/inception-bans /var/run/fail2ban

COPY conf/fail2ban.local /etc/fail2ban/fail2ban.local
COPY conf/jail.local /etc/fail2ban/jail.local
COPY conf/filter.d/ /etc/fail2ban/filter.d/
COPY conf/action.d/ /etc/fail2ban/action.d/
COPY tools/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
