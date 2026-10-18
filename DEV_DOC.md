# Developer Documentation

How to set up, build, run and maintain the Inception stack.

## Set up the environment from scratch

### Prerequisites
- A Linux virtual machine (e.g. Debian) with:
  - Docker Engine and the Docker Compose plugin
  - `make` and `git`
- Your user in the `docker` group, so `make` runs without `sudo`:
  ```sh
  sudo usermod -aG docker $USER   # then log out and back in
  ```
- The domain mapped to the machine, in `/etc/hosts`:
  ```
  127.0.0.1 aabi-mou.42.fr
  ```

### Configuration files
Clone the repository, then create the two git-ignored inputs.

**1. `srcs/.env`**: copy `srcs/.env.example` and fill it in. Format `KEY=value`, no spaces, no quotes, no passwords.

| Variable | Used by | Purpose |
|---|---|---|
| `DOMAIN_NAME` | nginx, wordpress | Site domain (`aabi-mou.42.fr`), certificate CN, WordPress URL |
| `MYSQL_DATABASE` | mariadb, wordpress | Database name |
| `MYSQL_USER` | mariadb, wordpress | Database user WordPress connects with |
| `DB_HOST` | wordpress | Database host: the `mariadb` service name |
| `MYSQL_PORT` | mariadb, wordpress | Database port (3306) |
| `WP_HOST` | nginx | PHP-FPM host: the `wordpress` service name |
| `WP_PORT` | nginx, wordpress | PHP-FPM port (9000) |
| `WP_TITLE` | wordpress | Site title |
| `WP_ADMIN_USER`, `WP_ADMIN_EMAIL` | wordpress | Administrator; the name must not contain "admin" |
| `WP_USER`, `WP_USER_EMAIL` | wordpress | Second (author) user |
| `NGINX_PORT` | nginx | HTTPS port (443), the only published port |
| `DATA_PATH` | compose, Makefile | Host folder for the volumes (`/home/aabi-mou/data`) |
| `ADMINER_HOST` | nginx | Adminer PHP-FPM host: the `adminer` service name (bonus) |
| `ADMINER_PORT` | nginx, adminer | Adminer PHP-FPM port (9001) (bonus) |
| `REDIS_HOST` | wordpress | Redis host: the `redis` service name (bonus) |
| `REDIS_PORT` | redis, wordpress | Redis port (6379) (bonus) |
| `FTP_USER` | ftp | FTP login name (bonus) |
| `FTP_PORT` | ftp, compose | FTP control port (21), published (bonus) |
| `FTP_PASV_MIN`, `FTP_PASV_MAX` | ftp, compose | Passive data port range (21100-21110), published (bonus) |
| `STATIC_HOST` | nginx | Static site host: the `static` service name (bonus) |
| `STATIC_PORT` | nginx, static | Static site HTTP port inside the network (8080) (bonus) |
| `FTP_PASV_ADDRESS` | ftp | Address sent to clients for passive connections: the host's IP (`127.0.0.1` for local tests) (bonus) |

`DB_HOST` is deliberately not called `MYSQL_HOST`: the MariaDB client reads `MYSQL_HOST` as its default server, which would break local root access in the database container.

**2. `secrets/`** at the repository root:

| File | Content | Mounted in |
|---|---|---|
| `db_password.txt` | Password of `MYSQL_USER` (value only) | mariadb, wordpress |
| `db_root_password.txt` | MariaDB root password (value only) | mariadb |
| `credentials.txt` | `WP_ADMIN_PASSWORD=...` and `WP_USER_PASSWORD=...`, one per line | wordpress |
| `redis_password.txt` | Redis password (bonus), value only, e.g. `openssl rand -hex 16` | redis, wordpress |
| `ftp_password.txt` | Password of `FTP_USER` (bonus), value only, e.g. `openssl rand -hex 16` | ftp |

Avoid `'` and `\` in passwords: they are inserted into SQL statements. `make` refuses to start if `srcs/.env`, `DATA_PATH` or a secret file is missing or empty.

## Build and launch

```sh
make
```
This runs `make check`, creates `$(DATA_PATH)/mariadb` and `$(DATA_PATH)/wordpress`, then runs `docker compose -f srcs/docker-compose.yml up -d --build`.

Startup sequence:
1. **mariadb** initializes the database on the first run (`tools/init.sh`), then becomes healthy once its TCP ping succeeds.
2. **wordpress** starts only after mariadb is healthy. On the first run it downloads WordPress, creates `wp-config.php`, installs the site and creates both users (`tools/setup.sh`).
3. **nginx** generates its certificate and its config from the template (`tools/entrypoint.sh`), then serves HTTPS.

Bonus: **adminer** (`requirements/bonus/adminer/`) also waits for mariadb to be healthy, and nginx waits for it. Its image contains PHP-FPM and the single Adminer file (`/var/www/adminer/index.php`, version pinned by `ADMINER_VERSION` in the Dockerfile). It has no volume and no secrets: users log in with the database credentials. NGINX does not have the file: its `location = /adminer` block sends `SCRIPT_FILENAME` with the path inside the adminer container. All bonus services live under `srcs/requirements/bonus/`.

Bonus: **fail2ban** (`requirements/bonus/fail2ban/`) starts after nginx. Its PID 1 is `fail2ban-server -f`. It works without any firewall:
1. nginx writes its access log to the `nginx_logs` volume (`/var/log/inception/access.log`) as well as to stdout.
2. fail2ban reads that log through two filters (`conf/filter.d/`):
   - WordPress: `POST /wp-login.php` or `/xmlrpc.php` answered with 200 (a failed login)
   - WordPress requests with a query string (`/wp-login.php?x=1`) count too, so they can't bypass the filter
   - Adminer: `GET` or `POST /adminer?...username=...` answered with 403 (a failed login)
3. On a ban, the custom action `conf/action.d/inception-banlist.conf` appends the IP to `/var/lib/inception-bans/<jail>.list` in the `bans` volume. On an unban, it removes the IP.
4. nginx mounts `bans` read-only. `conf/banlist.js` (njs, the `nginx-mod-http-js` package) checks the lists on each request, and `if ($banned) { return 403; }` blocks the IP.

This design needs no `NET_ADMIN` capability and no shared network namespace, and bans stay enforced when nginx crashes and restarts. nginx does not depend on fail2ban, so the site keeps working if fail2ban is down. The limits (`maxretry`, `findtime`, `bantime`) are in `conf/jail.local`. To test a filter against the log:
```sh
docker exec fail2ban fail2ban-regex /var/log/inception/access.log /etc/fail2ban/filter.d/inception-wordpress.conf
```

Bonus: **redis** (`requirements/bonus/redis/`) is WordPress's object cache, and wordpress waits for it to be healthy.
- The container runs as the `redis` user. `redis-server` is PID 1.
- `conf/redis.conf` makes it a pure cache: 128 MB, least-recently-used keys are evicted first, and nothing is persisted, so there is no volume.
- The password comes from the `redis_password` secret. `tools/entrypoint.sh` writes it to `/run/redis/auth.conf` (mode 600, included by the config), so it never appears in `ps`. The healthcheck passes it through `REDISCLI_AUTH`.
- On **every** start, `wordpress/tools/setup.sh` writes `WP_REDIS_HOST`, `WP_REDIS_PORT` and `WP_REDIS_PASSWORD` into `wp-config.php`, installs and activates the **Redis Object Cache** plugin (`redis-cache`), and enables its `wp-content/object-cache.php` drop-in. Each step is idempotent, so an existing installation gets Redis without `make fclean`.
- The plugin uses the native `php84-pecl-redis` client.

```sh
docker exec wordpress wp redis status --allow-root
docker exec -e REDISCLI_AUTH="$(cat secrets/redis_password.txt)" redis redis-cli -p 6379 info keyspace
```

Bonus: **ftp** (`requirements/bonus/ftp/`) runs vsftpd as PID 1 and mounts the `wordpress` volume read-write at `/var/www/html`.
- **Same owner as WordPress:** at first start, `tools/entrypoint.sh` creates `FTP_USER` with `useradd -o -u 65534 -g 65534`, the uid/gid of `nobody` that owns the WordPress files. Uploads are owned by `nobody`, so php-fpm can modify them, and FTP can modify WordPress's files. The password from the `ftp_password` secret is set on every start with `chpasswd`. `conf/pam-vsftpd` checks it against `/etc/shadow`.
- **Jail:** the user's home is `/var/www/html`, and `chroot_local_user=YES` keeps it there. `allow_writeable_chroot=YES` is required because that folder is writable.
- **FTPS:** a self-signed certificate is generated at startup (as in nginx). Logins and data transfers must use TLS 1.2 or 1.3.
- **Passive mode:** each transfer opens a data connection on one of the published ports `FTP_PASV_MIN`-`FTP_PASV_MAX`. Inside Docker, vsftpd would advertise its container IP, so `pasv_address` tells clients to use `FTP_PASV_ADDRESS` instead. Set it to the VM's IP to connect from another machine.
- **Config template:** vsftpd can't read environment variables, so `conf/vsftpd.conf.template` is filled with `envsubst` at startup, like nginx's config.

Published ports are therefore 443 (nginx), and 21 plus 21100-21110 (ftp, bonus).

Bonus: **static** (`requirements/bonus/static/`) is a one-page blog in plain HTML and CSS (`site/`), with no PHP.
- **Server:** BusyBox `httpd`, from Alpine's `busybox-extras` package, serves `/var/www/static` on `STATIC_PORT`. It runs as `nobody`, in the foreground (`-f`, PID 1), and logs requests (`-v`).
- **Routing:** nginx forwards `https://aabi-mou.42.fr/blog/` to it with `proxy_pass http://static:8080/`. The trailing `/` removes the `/blog` prefix, and `/blog` redirects to `/blog/` so the page's relative links (`style.css`, `#ai`) resolve correctly. `location ^~ /blog/` keeps the `.php` regex location from taking these requests.
- **No volume:** the files are baked into the image. Edit `site/`, then run `docker compose up -d --build static`.

Each script ends with `exec <daemon>`, so the service runs in the foreground as PID 1.

### Makefile targets

| Target | Command run |
|---|---|
| `all`, `up` | `check`, `mkdir -p` data folders, `docker compose up -d --build` |
| `down` | `docker compose down` |
| `stop`, `start` | `docker compose stop` / `start` |
| `ps`, `logs` | `docker compose ps` / `logs -f` |
| `clean` | `docker compose down --rmi all` |
| `fclean` | `docker compose down -v --rmi all`, then deletes `DATA_PATH` |
| `re` | `fclean` + `all` |
| `check` | Validates `srcs/.env`, `DATA_PATH` and the secrets |

## Manage containers and volumes

```sh
docker compose -f srcs/docker-compose.yml up -d --build wordpress   # rebuild one service
docker exec -it <container> sh                                      # shell in a container
docker exec <container> ps -o pid,args                              # PID 1 = the daemon
docker exec wordpress wp user list --allow-root                     # WordPress users
docker exec -it mariadb mariadb -u root -p                          # database shell
docker volume ls                                                    # srcs_mariadb, srcs_wordpress
docker volume inspect srcs_mariadb                                  # device = DATA_PATH/mariadb
docker network inspect srcs_inception                               # the bridge network
```

## Data storage and persistence

| Volume | Container path | Host path | Content |
|---|---|---|---|
| `srcs_mariadb` | `/var/lib/mysql` | `$(DATA_PATH)/mariadb` | Database files |
| `srcs_wordpress` | `/var/www/html` | `$(DATA_PATH)/wordpress` | WordPress files, uploads, plugins (read-only in nginx) |

Both are named volumes (`driver: local` with `type: none`, `o: bind`), so Docker manages them by name while the files live in `DATA_PATH`.

The fail2ban bonus adds two plain named volumes, stored by Docker rather than in `DATA_PATH`:

| Volume | Mounted in | Content |
|---|---|---|
| `srcs_nginx_logs` | nginx (rw), fail2ban (ro) | `access.log`. It is not rotated and grows until `make fclean`. |
| `srcs_bans` | fail2ban (rw), nginx (ro) | `<jail>.list` files with the banned IPs |

| Action | Data |
|---|---|
| `make down`, `make stop`, restart, crash, VM reboot | Kept |
| `make clean` | Kept (only images are removed) |
| `make fclean` | **Deleted**: volumes and `DATA_PATH` are removed |

The first-run setup in each script is skipped when data already exists, so changes to `srcs/.env` or `secrets/` only apply after `make fclean`. The data files belong to container users (`mysql`, `nobody`), so `make fclean` deletes them from inside a temporary container instead of requiring `sudo`.
