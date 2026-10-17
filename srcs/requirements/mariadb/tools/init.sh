#!/bin/sh
set -e

: "${MYSQL_PORT:?MYSQL_PORT is not set}"

DB_PASSWORD=$(cat /run/secrets/db_password)
DB_ROOT_PASSWORD=$(cat /run/secrets/db_root_password)

# The volume directory is created on the host by root; mariadbd runs as mysql
chown -R mysql:mysql /var/lib/mysql /run/mysqld

# First run only: an empty data directory means the database was never created
if [ ! -d /var/lib/mysql/mysql ]; then
    echo "[mariadb] first run: initializing ${MYSQL_DATABASE}"
    mariadb-install-db --user=mysql --datadir=/var/lib/mysql --skip-test-db > /dev/null

    # Bootstrap mode runs the SQL without starting the network server
    mariadbd --user=mysql --bootstrap <<SQL
FLUSH PRIVILEGES;
DROP USER IF EXISTS ''@'localhost';
CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASSWORD}';
FLUSH PRIVILEGES;
SQL
fi

# Replace the shell so mariadbd becomes PID 1 and receives stop signals directly
exec mariadbd --user=mysql --port="${MYSQL_PORT}"
