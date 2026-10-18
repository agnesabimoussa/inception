#!/bin/sh
set -e

for var in DOMAIN_NAME MYSQL_DATABASE MYSQL_USER DB_HOST MYSQL_PORT WP_PORT \
           WP_TITLE WP_ADMIN_USER WP_ADMIN_EMAIL WP_USER WP_USER_EMAIL \
           REDIS_HOST REDIS_PORT; do
    eval "value=\${$var}"
    [ -n "$value" ] || { echo "[wordpress] error: $var is not set" >&2; exit 1; }
done

# Subject rule: the administrator's username can't contain admin/administrator
case "$(echo "$WP_ADMIN_USER" | tr '[:upper:]' '[:lower:]')" in
    *admin*) echo "[wordpress] error: WP_ADMIN_USER must not contain 'admin'" >&2; exit 1 ;;
esac

DB_PASSWORD=$(cat /run/secrets/db_password)
WP_ADMIN_PASSWORD=$(grep '^WP_ADMIN_PASSWORD=' /run/secrets/credentials | cut -d= -f2-)
WP_USER_PASSWORD=$(grep '^WP_USER_PASSWORD=' /run/secrets/credentials | cut -d= -f2-)
REDIS_PASSWORD=$(cat /run/secrets/redis_password)

cd /var/www/html

# Download WordPress files into the volume (first run only)
if [ ! -f wp-load.php ]; then
    echo "[wordpress] downloading WordPress"
    wp core download --allow-root
fi

# Generate wp-config.php with the database connection (first run only)
if [ ! -f wp-config.php ]; then
    wp config create --allow-root \
        --dbname="${MYSQL_DATABASE}" \
        --dbuser="${MYSQL_USER}" \
        --dbpass="${DB_PASSWORD}" \
        --dbhost="${DB_HOST}:${MYSQL_PORT}"
fi

# Create the tables, the administrator and the second user (first run only)
if ! wp core is-installed --allow-root 2>/dev/null; then
    echo "[wordpress] installing site and users"
    wp core install --allow-root \
        --url="https://${DOMAIN_NAME}" \
        --title="${WP_TITLE}" \
        --admin_user="${WP_ADMIN_USER}" \
        --admin_password="${WP_ADMIN_PASSWORD}" \
        --admin_email="${WP_ADMIN_EMAIL}" \
        --skip-email
    wp user create --allow-root "${WP_USER}" "${WP_USER_EMAIL}" \
        --role=author \
        --user_pass="${WP_USER_PASSWORD}"
fi

# Bonus: Redis object cache. Runs on every start (each step is idempotent),
# so an existing installation is upgraded too.
wp config set WP_REDIS_HOST "${REDIS_HOST}" --allow-root --quiet
wp config set WP_REDIS_PORT "${REDIS_PORT}" --raw --allow-root --quiet
wp config set WP_REDIS_PASSWORD "${REDIS_PASSWORD}" --allow-root --quiet
wp plugin is-installed redis-cache --allow-root \
    || wp plugin install redis-cache --allow-root
wp plugin is-active redis-cache --allow-root \
    || wp plugin activate redis-cache --allow-root
# The object-cache.php drop-in is what sends WordPress's cache to Redis
[ -f wp-content/object-cache.php ] || wp redis enable --allow-root

# php-fpm workers run as nobody and must be able to write uploads, plugins...
chown -R nobody:nobody /var/www/html

# Replace the shell so php-fpm becomes PID 1; -F keeps it in the foreground
exec php-fpm84 -F
