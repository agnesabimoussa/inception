COMPOSE   = docker compose -f srcs/docker-compose.yml
ENV_FILE  = srcs/.env
SECRETS   = secrets/db_password.txt secrets/db_root_password.txt secrets/credentials.txt \
            secrets/redis_password.txt secrets/ftp_password.txt
DATA_PATH = $(shell grep '^DATA_PATH=' $(ENV_FILE) 2>/dev/null | cut -d= -f2-)

all: up

# Build the images and start the whole stack in the background
up: check
	mkdir -p $(DATA_PATH)/mariadb $(DATA_PATH)/wordpress
	$(COMPOSE) up -d --build

# Stop and remove the containers and the network (data is kept)
down:
	$(COMPOSE) down

# Pause / resume the containers without removing them
stop:
	$(COMPOSE) stop

start:
	$(COMPOSE) start

ps:
	$(COMPOSE) ps

logs:
	$(COMPOSE) logs -f

# Also remove the images built by the project
clean:
	$(COMPOSE) down --rmi all

# Also remove the volumes and the data on the host: next "make" starts from scratch.
# The data files belong to container users (mysql, nobody), so they are deleted
# from inside a throwaway container instead of requiring sudo.
fclean: check
	$(COMPOSE) down -v --rmi all
	docker run --rm -v $(DATA_PATH):/data alpine:3.23 find /data -mindepth 1 -delete
	rm -rf $(DATA_PATH)

re: fclean all

# Fail early with a clear message if the local config is missing
check:
	@test -f $(ENV_FILE) || { echo "Error: $(ENV_FILE) is missing (copy srcs/.env.example)"; exit 1; }
	@test -n "$(DATA_PATH)" || { echo "Error: DATA_PATH is not set in $(ENV_FILE)"; exit 1; }
	@for f in $(SECRETS); do \
		test -s $$f || { echo "Error: $$f is missing or empty"; exit 1; }; \
	done

.PHONY: all up down stop start ps logs clean fclean re check
