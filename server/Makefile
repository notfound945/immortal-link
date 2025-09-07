# Define image variables
REGISTRY_IMAGE := registry.cn-shenzhen.aliyuncs.com/notfound945/immortal-link:latest
LOCAL_IMAGE := immortal-link:latest

# Default target
.DEFAULT_GOAL := pull-and-tag

# Declare phony targets
.PHONY: pull-and-tag pull tag clean

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