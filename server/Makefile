# Define image variables
REGISTRY_IMAGE := registry.cn-shenzhen.aliyuncs.com/notfound945/immortal-link:latest
LOCAL_IMAGE := immortal-link:latest
CONTAINER ?= immortal-link
PORT ?= 65530

# Default target
.DEFAULT_GOAL := pull-and-tag

# Declare phony targets
.PHONY: pull-and-tag pull tag clean restart

# Pull and tag image (default target)
pull-and-tag: pull tag
	@echo "Completed image pull and tag"

# Pull image
pull:
	@echo "Pulling image: $(REGISTRY_IMAGE)"
	docker pull $(REGISTRY_IMAGE)

# Tag image
tag:
	@echo "Tagging image as: $(LOCAL_IMAGE)"
	docker tag $(REGISTRY_IMAGE) $(LOCAL_IMAGE)

# Clean local images (optional)
clean:
	@echo "Removing local image: $(LOCAL_IMAGE)"
	docker rmi $(LOCAL_IMAGE) || true
	@echo "Removing registry image: $(REGISTRY_IMAGE)"
	docker rmi $(REGISTRY_IMAGE) || true

# Start container
start:
	@echo "Starting container: $(LOCAL_IMAGE)"
	docker compose up -d

# Restart container
restart:
	@echo "Restarting container: $(LOCAL_IMAGE)"
	docker compose restart

# Stop container
stop:
	@echo "Stopping container: $(LOCAL_IMAGE)"
	docker compose down

# View container logs
logs:
	docker compose logs -f $(CONTAINER)

# CLI usage
cli:
	@if [ -z "$(CMD)" ]; then echo "Usage: make cli CMD='send <client> <message>|broadcast <message>|wol <client> <mac>|clients|quit'"; exit 1; fi
	docker exec -it $(CONTAINER) lua cli.lua $(CMD)

cli-send:
	@if [ -z "$(CLIENT)" ] || [ -z "$(MESSAGE)" ]; then echo "Usage: make cli-send CLIENT=<client-id> MESSAGE=<text>"; exit 1; fi
	docker exec -it $(CONTAINER) lua cli.lua send $(CLIENT) $(MESSAGE)

cli-wol:
	@if [ -z "$(CLIENT)" ] || [ -z "$(MAC)" ]; then echo "Usage: make cli-wol CLIENT=<client-id> MAC=<mac-address>"; exit 1; fi
	docker exec -it $(CONTAINER) lua cli.lua wol $(CLIENT) $(MAC)

cli-broadcast:
	@if [ -z "$(MESSAGE)" ]; then echo "Usage: make cli-broadcast MESSAGE=<text>"; exit 1; fi
	docker exec -it $(CONTAINER) lua cli.lua broadcast $(MESSAGE)

cli-clients:
	docker exec -it $(CONTAINER) lua cli.lua clients

cli-quit:
	docker exec -it $(CONTAINER) lua cli.lua quit

