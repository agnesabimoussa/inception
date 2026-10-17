# User Documentation

How to use and administer the Inception stack. All commands are run from the repository root on the virtual machine.

## Services

| Service | Role | Access |
|---|---|---|
| NGINX | Web server and only entry point, HTTPS (TLSv1.2/TLSv1.3) | `https://aabi-mou.42.fr`, port 443 |
| WordPress + PHP-FPM | The website and its administration panel | Through NGINX only |
| MariaDB | Database storing all WordPress content | Internal only, not reachable from the host |

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

## Credentials

Credentials are stored locally and are never committed to git.

| What | Where |
|---|---|
| Usernames, emails, domain | `srcs/.env` |
| WordPress passwords (admin and user) | `secrets/credentials.txt` |
| Database user password | `secrets/db_password.txt` |
| Database root password | `secrets/db_root_password.txt` |

Accounts are created on the first start only. Changing these files afterwards does not update existing accounts: change passwords from the administration panel (Users > Profile), or reset everything with `make fclean && make`, which **deletes all site data**.

## Check that the services are running

```sh
make ps
```
All three containers should be `Up`, and `mariadb` should be `(healthy)`.

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
