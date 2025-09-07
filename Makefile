REGISTRY ?= registry.cn-shenzhen.aliyuncs.com/notfound945/immortal-link
IMAGE ?= immortal-link:latest
CONTAINER ?= immortal-link
PORT ?= 65530

.PHONY: help build-arm64 build-amd64 push pull run exec cli \
        cli-send cli-wol cli-broadcast cli-clients cli-quit run-local \
        server-up server-down client-up

help:
	@echo "Make targets:"
	@echo "  build-arm64        - Docker build for ARM64 host"
	@echo "  build-amd64        - Docker build for AMD64 (cross-build)"
	@echo "  push               - Tag and push $(IMAGE) to $(REGISTRY):latest"
	@echo "  pull               - Pull $(REGISTRY):latest and tag as $(IMAGE)"
	@echo "  run                - Run container on host port $(PORT) -> 65530"
	@echo "  exec               - Enter container shell"
	@echo "  cli                - Run CLI inside container, e.g., make cli CMD='clients'"
	@echo "  cli-send           - Send to client, e.g., make cli-send CLIENT=client-1 MESSAGE=hello"
	@echo "  cli-wol            - WOL a client, e.g., make cli-wol CLIENT=client-1 MAC=6c:1f:..."
	@echo "  cli-broadcast      - Broadcast message, e.g., make cli-broadcast MESSAGE=hello"
	@echo "  cli-clients        - List clients"
	@echo "  cli-quit           - Gracefully quit server"
	@echo "  run-local          - Run server locally, e.g., make run-local ARGS='--daemon'"
	@echo "  server-up          - docker compose up -d in server/"
	@echo "  server-down        - docker compose down in server/"
	@echo "  client-up          - run local client: cd client && lua client.lua"

build-arm64:
	docker build -f server/Dockerfile.server -t $(IMAGE) .

build-amd64:
	docker build -f server/Dockerfile.server --platform linux/amd64 -t $(IMAGE) .

push:
	docker tag $(IMAGE) $(REGISTRY):latest
	docker push $(REGISTRY):latest

pull:
	docker pull $(REGISTRY):latest
	docker tag $(REGISTRY):latest $(IMAGE)

run:
	docker run -it --rm -p $(PORT):65530 --name $(CONTAINER) $(IMAGE)

exec:
	docker exec -it $(CONTAINER) /bin/sh

run-local:
	# Example: make run-local ARGS='--daemon --admin-port 65531'
	lua server/server.lua $(ARGS)

server-up:
	cd server && docker compose up -d

server-down:
	cd server && docker compose down

client-up:
	cd client && lua client.lua