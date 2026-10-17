*This project has been created as part of the 42 curriculum by aabi-mou.*

# Outline
1. [Description](#description)
2. [Docker Usage and Design Choices](#docker-usage-and-design-choices)
3. [Virtual Machines vs Docker](#virtual-machines-vs-docker)
4. [Secrets vs Environment Variables](#secrets-vs-environment-variables)
5. [Docker Network vs Host Network](#docker-network-vs-host-network)
6. [Docker Volumes vs Bind Mounts](#docker-volumes-vs-bind-mounts)
7. [Instructions](#instructions)
8. [AI Usage](#ai-usage)
9. [Resources](#resources)


# Description

Inception sets up a small web infrastructure with Docker Compose inside a virtual machine: a WordPress website served over HTTPS. Each service runs in its own container, built from its own Dockerfile on Alpine Linux. No ready-made images are used.

- **NGINX**: the only entry point, HTTPS on port 443 with TLSv1.2/TLSv1.3 only.
- **WordPress + PHP-FPM**: runs the PHP code; NGINX forwards PHP requests to it over FastCGI on port 9000.
- **MariaDB**: stores the WordPress database; WordPress connects to it on port 3306.

The containers communicate over a dedicated bridge network, restart automatically after a crash, and keep their data in two named volumes stored in `/home/aabi-mou/data` on the host.

![Requirement](assets/requirement.png)

## Docker Usage and Design Choices
- Linux distibution: Alpine Reason: very small image size compared to Debian.
- Database: MariaDB. A volume is needed to persist data even if container is deleted.
- PHP-FPM (stands for PHP FastCGI Process Manager) is a service that runs PHP code and returns the results to a web server (NGINX here).
- WordPress is a CMS(content management system) that let's anyone build websites without coding knowledge.
- Base image: `alpine:3.23`, the penultimate stable Alpine release, as required. Images are tagged `<service>:inception`; the `latest` tag is never used.
- One service per container: each entrypoint script prepares its service on the first run, then `exec`s the daemon in the foreground so it becomes PID 1. No `tail -f` or infinite loops.
- Configuration: every setting comes from `srcs/.env`. Passwords are Docker secrets read from `/run/secrets/`; they never appear in images or environment variables.
- TLS: NGINX generates a self-signed certificate for `aabi-mou.42.fr` at startup. Plain HTTP is not served.
- Startup order: a MariaDB healthcheck (TCP ping as the WordPress user) makes WordPress wait until the database accepts connections.
- Storage: named volumes using the `local` driver with bind options, so Docker manages them by name while the data lives in `DATA_PATH` on the host.

Project sources:
```
.
├── Makefile                 # builds and manages the stack through docker compose
├── secrets/                 # passwords, one file per secret (git-ignored)
└── srcs/
    ├── .env                 # configuration (git-ignored), template: .env.example
    ├── docker-compose.yml   # services, network, volumes and secrets
    └── requirements/
        ├── mariadb/         # Dockerfile, conf/zz-inception.cnf, tools/init.sh
        ├── wordpress/       # Dockerfile, conf/www.conf, conf/php.ini, tools/setup.sh
        └── nginx/           # Dockerfile, conf/inception.conf.template, tools/entrypoint.sh
```


## Virtual Machines vs Docker
Both add an abstraction layer between applications and the physical machine, but at different levels.

A virtual machine runs on a **hypervisor**, which splits the host's hardware resources (CPU, memory, storage) between VMs. Each VM boots its own full operating system, with its own kernel, on virtualized hardware. This gives strong isolation, but VMs are heavy: they take up gigabytes and take a while to start.

Docker uses **containerization**: it packages an application and its dependencies into an isolated process that **shares the host's kernel**. A container is created from an **image**, and the image is built from a **Dockerfile**, which is the recipe listing the steps to build it. Containers are lightweight, start in seconds, and behave the same in every environment.

- **Use VMs when** you need full isolation or different operating systems/kernels (e.g. running Windows on a Linux host).
- **Use Docker when** you want lightweight, reproducible services, such as a microservices architecture where each service runs in its own container.

## Secrets vs Environment Variables
**Environment variables** (often loaded from a `.env` file) configure an application: its port, database hostname, debug mode, and so on. They can hold passwords, but that isn't safe. Their values can leak through `docker inspect`, through `/proc/<pid>/environ`, in logs, or to child processes.

**Docker secrets** are the safer way to pass sensitive data such as passwords or API keys. Each secret is stored in its own file and mounted read-only inside the container at `/run/secrets/<name>`, and only the services that ask for it get it. The application reads the value from that file instead of from an environment variable, so it never shows up in the container's configuration.

## Docker Network vs Host Network
On a **Docker (bridge) network**, each container gets its own IP address and network stack, isolated from the host. Containers on the same user-defined network can reach each other by service name through Docker's built-in DNS. To reach a container from outside, you have to publish a port explicitly (`-p host_port:container_port`), and the host then forwards that traffic into the container.

On the **host network**, the container shares the host's network stack directly, with no isolation and no separate IP. Its services listen straight on the host's ports, so port publishing (`-p`) isn't needed and is ignored. This avoids a little overhead but gives up isolation and can cause port conflicts.

## Docker Volumes vs Bind Mounts
Both keep data alive after a container is deleted. The difference is who manages where the data lives.

A **Docker volume** is created and managed by Docker, which stores it in its own area (usually `/var/lib/docker/volumes/`). It's referenced by name, works the same on any host, and is the recommended choice for persistent data such as databases.

A **bind mount** maps a specific path on the host (e.g. `/home/user/data`) straight into the container. It's handy for development or for sharing files with the host, but it depends on the host's directory layout and permissions, which makes it less portable.


# Instructions

### Prerequisites
- A Linux virtual machine with Docker Engine, the Docker Compose plugin and `make`.
- The domain pointing to the local machine: add `127.0.0.1 aabi-mou.42.fr` to `/etc/hosts`.

### Configuration
1. Copy `srcs/.env.example` to `srcs/.env` and fill in the values (non-secret settings only, `KEY=value` without spaces).
2. Create the `secrets/` folder at the repository root with these files (all ignored by git):

| File | Content |
|---|---|
| `db_password.txt` | Password of `MYSQL_USER`, value only |
| `db_root_password.txt` | MariaDB root password, value only |
| `credentials.txt` | `WP_ADMIN_PASSWORD=...` and `WP_USER_PASSWORD=...`, one per line |

Avoid `'` and `\` in passwords: they are inserted into SQL statements.

### Usage
From the repository root:
```sh
make
```
The first start downloads and installs WordPress, which can take a few minutes. Then open https://aabi-mou.42.fr (accept the self-signed certificate warning). The administration panel is at https://aabi-mou.42.fr/wp-admin.

| Command | Effect |
|---|---|
| `make` / `make up` | Check the configuration, create the data folders, build the images and start the containers |
| `make ps` | Show the status of the containers |
| `make logs` | Follow the logs of all services |
| `make stop` / `make start` | Pause / resume the containers |
| `make down` | Remove the containers and the network; data is kept |
| `make clean` | `make down` and remove the project images |
| `make fclean` | `make clean`, remove the volumes and delete all data in `DATA_PATH` |
| `make re` | `make fclean` then `make` |

See [USER_DOC.md](USER_DOC.md) for day-to-day use and [DEV_DOC.md](DEV_DOC.md) for setup and internals.


# AI Usage
AI was used in this project for learning purposes only.

# Resources
- Docker docs: https://docs.docker.com/?uuid=93AB6D6A-89CE-4676-A763-4AF0BFD36D9C
- Docker desktop Gordon AI
- Dockerfile best practices: https://docs.docker.com/build/building/best-practices/
- Docker Compose secrets: https://docs.docker.com/compose/how-tos/use-secrets/
- Docker volumes: https://docs.docker.com/engine/storage/volumes/
- Alpine Linux releases: https://alpinelinux.org/releases/
- MariaDB documentation: https://mariadb.com/docs/
- NGINX, configuring HTTPS servers: https://nginx.org/en/docs/http/configuring_https_servers.html
- PHP-FPM configuration: https://www.php.net/manual/en/install.fpm.configuration.php
- WP-CLI commands: https://developer.wordpress.org/cli/commands/