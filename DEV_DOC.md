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

`DB_HOST` is deliberately not called `MYSQL_HOST`: the MariaDB client reads `MYSQL_HOST` as its default server, which would break local root access in the database container.

**2. `secrets/`** at the repository root:

| File | Content | Mounted in |
|---|---|---|
| `db_password.txt` | Password of `MYSQL_USER` (value only) | mariadb, wordpress |
| `db_root_password.txt` | MariaDB root password (value only) | mariadb |
| `credentials.txt` | `WP_ADMIN_PASSWORD=...` and `WP_USER_PASSWORD=...`, one per line | wordpress |

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

| Action | Data |
|---|---|
| `make down`, `make stop`, restart, crash, VM reboot | Kept |
| `make clean` | Kept (only images are removed) |
| `make fclean` | **Deleted**: volumes and `DATA_PATH` are removed |

The first-run setup in each script is skipped when data already exists, so changes to `srcs/.env` or `secrets/` only apply after `make fclean`. The data files belong to container users (`mysql`, `nobody`), so `make fclean` deletes them from inside a temporary container instead of requiring `sudo`.
