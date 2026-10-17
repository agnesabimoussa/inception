# Evaluator Guide

A step-by-step checklist to evaluate this project without missing a requirement. Each step gives the command, what it checks, and the expected result. Run everything **inside the virtual machine**, from the repository root, unless stated otherwise.

Reference values used below (from `srcs/.env`):

| Item | Value |
|---|---|
| Domain | `aabi-mou.42.fr` |
| Containers / services | `nginx`, `wordpress`, `mariadb` |
| Images | `nginx:inception`, `wordpress:inception`, `mariadb:inception` |
| Volumes | `srcs_mariadb`, `srcs_wordpress` |
| Network | `srcs_inception` |
| Data on host | `/home/aabi-mou/data` |

---

## 0. Preliminaries

### 0.1 Credentials are not in the repository
```sh
git ls-files | grep -E '(^|/)\.env$|^secrets/'
```
**Expected:** no output. Only `srcs/.env.example` (placeholders) is tracked; `srcs/.env` and `secrets/` are git-ignored.

```sh
grep -rniE 'password|passwd' srcs/requirements/*/Dockerfile
```
**Expected:** no output. No password is written in any Dockerfile.

### 0.2 Local configuration exists
```sh
ls srcs/.env secrets/
```
**Expected:** `srcs/.env` and `credentials.txt  db_password.txt  db_root_password.txt`.

### 0.3 Start from a clean Docker state
```sh
docker stop $(docker ps -qa); docker rm $(docker ps -qa); docker rmi -f $(docker images -qa); \
docker volume rm $(docker volume ls -q); docker network rm $(docker network ls -q) 2>/dev/null
```
**Expected:** errors about empty lists or default networks are normal. Afterwards `docker ps -a` and `docker images` are empty.

---

## 1. General rules

### 1.1 Repository layout
```sh
ls; ls srcs srcs/requirements
```
**Expected:** `Makefile` at the root, all configuration in `srcs/`, one folder per service in `srcs/requirements/` (`mariadb`, `nginx`, `wordpress`).

### 1.2 Forbidden network options
```sh
grep -nE 'network_mode|network: *host|links:|--link' srcs/docker-compose.yml
grep -n 'networks:' srcs/docker-compose.yml
```
**Expected:** first command prints nothing; second command prints `networks:` lines (the network is declared).

### 1.3 No infinite-loop hacks
```sh
grep -rnE 'tail -f|sleep infinity|while true|bash' srcs/requirements Makefile
```
**Expected:** no output. Each entrypoint ends with `exec <daemon>` in the foreground.

```sh
tail -1 srcs/requirements/*/tools/*.sh
```
**Expected:** `exec mariadbd ...`, `exec nginx -g 'daemon off;'`, `exec php-fpm84 -F`.

### 1.4 Base images and tags
```sh
grep -h '^FROM' srcs/requirements/*/Dockerfile
grep -rn 'latest' srcs Makefile
grep -n 'image:' srcs/docker-compose.yml
```
**Expected:**
- every Dockerfile uses `FROM alpine:3.23` (no ready-made images);
- `latest` appears nowhere;
- images are named after their service: `mariadb:inception`, `wordpress:inception`, `nginx:inception`.

Check that 3.23 is the **penultimate** stable release at https://alpinelinux.org/releases/.

### 1.5 The Makefile builds through docker compose
```sh
make -n up
```
**Expected:** prints `docker compose -f srcs/docker-compose.yml up -d --build` (without running it).

---

## 2. Build and start

```sh
make
```
**Expected:** three images are built, then `mariadb Healthy`, `wordpress Started`, `nginx Started`. The first run installs WordPress in the background: wait about 1 to 3 minutes before testing the site.

```sh
make logs        # Ctrl+C to quit
```
**Expected:** `mariadb: ready for connections`, `wordpress: Success: Created user 2.` then `ready to handle connections`.

```sh
make ps
```
**Expected:** three containers `Up`, `mariadb` marked `(healthy)`. Only nginx publishes a port: `0.0.0.0:443->443/tcp`. wordpress shows `9000/tcp` and mariadb `3306/tcp` (internal, not published).

### 2.1 One process per container (PID 1)
```sh
for c in nginx wordpress mariadb; do echo "$c:"; docker exec $c ps -o pid,args | head -2; done
```
**Expected:** PID 1 is `nginx: master process`, `php-fpm: master process` and `mariadbd` respectively; no shell, no `tail`.

---

## 3. Docker network

```sh
docker network ls | grep inception
docker network inspect srcs_inception -f '{{range .Containers}}{{.Name}} {{end}}'
```
**Expected:** a `bridge` network `srcs_inception` connecting `nginx wordpress mariadb`.

---

## 4. NGINX with TLS

### 4.1 Domain
```sh
grep aabi-mou.42.fr /etc/hosts
```
**Expected:** `127.0.0.1 aabi-mou.42.fr`.

### 4.2 HTTPS works, HTTP does not
```sh
curl -kI https://aabi-mou.42.fr
curl -I http://aabi-mou.42.fr
```
**Expected:** first command `HTTP/1.1 200 OK`; second command `Failed to connect ... Connection refused` (port 80 is not open).

In a browser, `https://aabi-mou.42.fr` shows the WordPress site after accepting the self-signed certificate warning. The site must not show the WordPress installation page.

### 4.3 TLS versions
```sh
curl -skI --tlsv1.2 --tls-max 1.2 https://aabi-mou.42.fr | head -1
curl -skI --tlsv1.3 https://aabi-mou.42.fr | head -1
curl -skI --tlsv1.1 --tls-max 1.1 https://aabi-mou.42.fr; echo "exit code: $?"
```
**Expected:** `HTTP/1.1 200 OK` for TLS 1.2 and 1.3; TLS 1.1 fails (no output and a non-zero exit code).

```sh
openssl s_client -connect aabi-mou.42.fr:443 </dev/null 2>/dev/null | grep -E 'subject|Protocol'
```
**Expected:** `subject=O=42, CN=aabi-mou.42.fr` and a `Protocol` line showing `TLSv1.3`.

### 4.4 NGINX is the only entry point
```sh
grep -n -A1 'ports:' srcs/docker-compose.yml
docker exec nginx netstat -tln
```
**Expected:** only nginx has a `ports:` entry (`${NGINX_PORT}`, i.e. 443); nginx listens only on `:443`.

---

## 5. WordPress + PHP-FPM and its volume

### 5.1 No NGINX in the WordPress container
```sh
docker exec wordpress which nginx; echo "exit code: $?"
grep -i nginx srcs/requirements/wordpress/Dockerfile
```
**Expected:** `which` prints nothing with exit code `1`; the Dockerfile does not install nginx.

### 5.2 Users and administrator name
```sh
docker exec wordpress wp user list --allow-root --fields=user_login,roles
```
**Expected:** two users: one `administrator` and one `author`. The administrator's name contains neither `admin` nor `administrator` (any case).

### 5.3 Functional test
1. Open `https://aabi-mou.42.fr/wp-admin` and log in as the administrator (username in `srcs/.env`, password in `secrets/credentials.txt`).
   **Expected:** the WordPress Dashboard.
2. Edit a page (e.g. Pages > Sample Page), change some text, click **Update**, then reload the site.
   **Expected:** the change is visible.
3. Log in as the second user (or open a post while logged in) and add a comment.
   **Expected:** the comment appears under the post.

### 5.4 Volume
```sh
docker volume ls
docker volume inspect srcs_wordpress -f '{{.Options.device}}'
ls /home/aabi-mou/data/wordpress | head -3
```
**Expected:** volume `srcs_wordpress` exists, its device is `/home/aabi-mou/data/wordpress`, and that folder contains the WordPress files (`index.php`, `license.txt`, ...).

---

## 6. MariaDB and its volume

### 6.1 No NGINX in the MariaDB container
```sh
docker exec mariadb which nginx; echo "exit code: $?"
```
**Expected:** nothing printed, exit code `1`.

### 6.2 Database access
```sh
docker exec mariadb mariadb -u root -e 'SELECT 1'
```
**Expected:** `ERROR 1045 (28000): Access denied` (root needs a password).

```sh
docker exec -it mariadb mariadb -u root -p
```
Enter the password from `secrets/db_root_password.txt`, then:
```sql
SHOW DATABASES;
SELECT user, host FROM mysql.user;
USE wordpress;
SHOW TABLES;
SELECT user_login FROM wp_users;
exit
```
**Expected:**
- databases include `wordpress` (no `test` database);
- users: `MYSQL_USER` on host `%`, `root` on `localhost`, plus system accounts `mariadb.sys` and `mysql`;
- `wordpress` contains the `wp_*` tables (not empty);
- `wp_users` lists the two WordPress users.

### 6.3 Volume
```sh
docker volume inspect srcs_mariadb -f '{{.Options.device}}'
sudo ls /home/aabi-mou/data/mariadb
```
**Expected:** device `/home/aabi-mou/data/mariadb`; the folder contains the database files (`ibdata1`, `mysql/`, `wordpress/`, ...).

---

## 7. Configuration through .env and secrets

```sh
grep -n 'env_file\|secrets:' srcs/docker-compose.yml
docker exec wordpress ls /run/secrets
for c in nginx wordpress mariadb; do docker inspect $c -f '{{range .Config.Env}}{{println .}}{{end}}'; done | grep -i pass
```
**Expected:** every service uses `env_file: .env`; secrets are mounted as files (`credentials  db_password`); the last command prints nothing: no password in the containers' environment.

---

## 8. Restart after a crash

```sh
sudo kill -9 $(docker inspect -f '{{.State.Pid}}' mariadb)
sleep 10; make ps
```
**Expected:** mariadb is `Up` again (a few seconds old) and becomes `(healthy)`. Repeat with `wordpress` and `nginx`.

`docker kill` / `docker stop` count as a manual stop, so Docker does not restart the container in that case. A crash is simulated by killing the process.

---

## 9. Persistence

1. Make sure the edit and the comment from step 5.3 exist.
2. Reboot the virtual machine:
   ```sh
   sudo reboot
   ```
3. After the reboot, from the repository root:
   ```sh
   make ps            # containers restart automatically; if not, run: make
   ```
4. Reload `https://aabi-mou.42.fr`.

**Expected:** the site works and the page edit and the comment are still there. WordPress is not reinstalled (`make logs` shows no `downloading WordPress` line).

Optional: `make down && make` gives the same result.

---

## 10. Documentation

```sh
head -1 README.md; ls README.md USER_DOC.md DEV_DOC.md
```
**Expected:** the first line is the italic sentence *This project has been created as part of the 42 curriculum by aabi-mou.* All three files exist. The README contains Description, Instructions and Resources sections, an AI usage description, and the four comparisons (VMs vs Docker, Secrets vs Environment Variables, Docker Network vs Host Network, Docker Volumes vs Bind Mounts).