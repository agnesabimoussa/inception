FROM alpine:3.23

# vsftpd, openssl for the self-signed certificate, shadow for useradd -o
# (FTP user with the same uid as nobody), envsubst to fill the config template
RUN apk add --no-cache vsftpd openssl shadow gettext-envsubst \
    && mkdir -p /etc/vsftpd/ssl /etc/vsftpd/templates /var/run/vsftpd/empty /var/www/html

COPY conf/vsftpd.conf.template /etc/vsftpd/templates/vsftpd.conf.template
# Alpine's vsftpd ships no PAM file: check the password against /etc/shadow
COPY conf/pam-vsftpd /etc/pam.d/vsftpd
COPY tools/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ARG FTP_PORT
ARG FTP_PASV_MIN
ARG FTP_PASV_MAX
EXPOSE ${FTP_PORT} ${FTP_PASV_MIN}-${FTP_PASV_MAX}

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
