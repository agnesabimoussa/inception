# User Documentation

How to use and administer the Inception stack. All commands are run from the repository root on the virtual machine.

## Services

| Service | Role | Access |
|---|---|---|
| NGINX | Web server and only entry point, HTTPS (TLSv1.2/TLSv1.3) | `https://aabi-mou.42.fr`, port 443 |
| WordPress + PHP-FPM | The website and its administration panel | Through NGINX only |
| MariaDB | Database storing all WordPress content | Internal only, not reachable from the host |
| Adminer (bonus) | Web interface to view and edit the database tables | `https://aabi-mou.42.fr/adminer`, through NGINX |
| Fail2ban (bonus) | Bans IPs that fail too many logins | Internal only, managed with `fail2ban-client` |
| Redis (bonus) | In-memory cache that speeds up WordPress | Internal only, password protected |
| FTP server (bonus) | Access to the WordPress files with an FTP client (FTPS) | `aabi-mou.42.fr`, port 21 (passive ports 21100-21110) |
| Static website (bonus) | *Byte Brief*, a one-page tech blog (HTML/CSS) | `https://aabi-mou.42.fr/blog/`, through NGINX |

## Start and stop

| Command | Effect |
|---|---|
| `make` | Build (if needed) and start the stack |
| `make stop` | Pause the containers |
| `make start` | Resume paused containers |
| `make down` | Stop and remove the containers; the website data is kept |

The very first start installs WordPress and can take a few minutes. Later starts take a few seconds.

## Access the website

1. Make sure `/etc/hosts` contains `127.0.0.1 aabi-mou.42.fr`.
2. Open **https://aabi-mou.42.fr** in a browser.
3. The certificate is self-signed, so the browser shows a warning: accept it to continue.

Administration panel: **https://aabi-mou.42.fr/wp-admin**

Two WordPress accounts exist:

| Account | Role | Username |
|---|---|---|
| Administrator | Full control of the site | `WP_ADMIN_USER` in `srcs/.env` |
| Regular user | Author: can write and publish posts | `WP_USER` in `srcs/.env` |

## Access the database with Adminer (bonus)

Open **https://aabi-mou.42.fr/adminer** and log in with:

| Field | Value |
|---|---|
| System | `MySQL / MariaDB` |
| Server | `mariadb` |
| Username | `MYSQL_USER` in `srcs/.env` |
| Password | content of `secrets/db_password.txt` |
| Database | `MYSQL_DATABASE` in `srcs/.env` (or leave empty) |

The `wp_*` tables can then be browsed and edited. Changes are written directly to the WordPress database, so edit with care.

The MariaDB `root` account only accepts local connections from inside the database container, so it cannot log in through Adminer. This is intentional.

## Brute-force protection with Fail2ban (bonus)

An IP that fails **5 logins within 10 minutes** is banned for **10 minutes**. During the ban, every page returns `403 Forbidden`.

Watched logins:
- WordPress: `/wp-login.php`, plus `/xmlrpc.php`, which this site does not use
- Adminer: `/adminer`

```sh
docker exec fail2ban fail2ban-client status                          # jails: adminer, wordpress
docker exec fail2ban fail2ban-client status wordpress                # banned IPs of a jail
docker exec fail2ban fail2ban-client set wordpress unbanip <ip>      # lift a ban now
```

When testing from the machine itself, Docker hands the requests to NGINX from its bridge gateway address (e.g. `172.18.0.1`), so a ban blocks **all local access** until it expires or is lifted with `unbanip`.

## Redis cache (bonus)

The site looks the same with or without Redis. With it, WordPress keeps the results of repeated database queries (settings, menus, posts) in memory, so pages need fewer MariaDB queries. If Redis stops, the site keeps working directly from MariaDB.

```sh
docker exec wordpress wp redis status --allow-root     # Status: Connected
docker exec wordpress wp plugin list --allow-root      # redis-cache is active
```

## Manage files with FTP (bonus)

The FTP server gives access to the website's files: themes, plugins and uploads in `wp-content/`. Encryption (TLS) is required, so plain FTP clients are refused.

With **FileZilla** (File > Site Manager > New site):

| Setting | Value |
|---|---|
| Protocol | FTP |
| Host / Port | `aabi-mou.42.fr` / `21` |
| Encryption | Require explicit FTP over TLS |
| Logon type | Normal |
| User / Password | `FTP_USER` in `srcs/.env` / content of `secrets/ftp_password.txt` |

The certificate is self-signed: accept it on the first connection. `/` is the WordPress folder; you cannot go above it.

From the command line:
```sh
curl --ssl-reqd -k --user ftp_aabi:<password> ftp://aabi-mou.42.fr/                  # list files
curl --ssl-reqd -k --user ftp_aabi:<password> -T file.txt ftp://aabi-mou.42.fr/      # upload
```

## Static blog (bonus)

Open **https://aabi-mou.42.fr/blog/** for *Byte Brief*, a one-page tech blog. It is separate from WordPress: plain HTML and CSS, no database, no login. The posts are sample content.

To change it, edit `srcs/requirements/bonus/static/site/index.html` or `style.css`, then rebuild only this service:
```sh
docker compose -f srcs/docker-compose.yml up -d --build static
```

## Credentials

Credentials are stored locally and are never committed to git.

| What | Where |
|---|---|
| Usernames, emails, domain | `srcs/.env` |
| WordPress passwords (admin and user) | `secrets/credentials.txt` |
| Database user password | `secrets/db_password.txt` |
| Database root password | `secrets/db_root_password.txt` |
| Redis password (bonus) | `secrets/redis_password.txt` |
| FTP user / password (bonus) | `FTP_USER` in `srcs/.env` / `secrets/ftp_password.txt` |

Accounts are created on the first start only. Changing these files afterwards does not update existing accounts: change passwords from the administration panel (Users > Profile), or reset everything with `make fclean && make`, which **deletes all site data**.

## Check that the services are running

```sh
make ps
```
All three containers should be `Up`, and `mariadb` should be `(healthy)`. With the bonus, `adminer`, `fail2ban`, `redis`, `ftp` and `static` are extra containers and should be `Up` too (`redis` also `(healthy)`).

```sh
make logs
```
Shows the logs of all services (`Ctrl+C` to quit). Healthy signs:
- mariadb: `ready for connections`
- wordpress: `ready to handle connections`
- nginx: no `emerg` or `error` lines

Quick checks:
```sh
curl -k https://aabi-mou.42.fr                              # returns the site's HTML
docker exec -it mariadb mariadb -u root -p                  # database shell (root password)
```

If a container keeps restarting, `make logs` shows the reason, usually a missing value in `srcs/.env` or `secrets/`.
