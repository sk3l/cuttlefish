#MAJOR?=0
#MINOR?=1

#VERSION=$(MAJOR).$(MINOR)
SHELL:=/bin/bash

APP_NAME:=cuttlefish
APP_PREFIX:=sk3l

# Our docker Hub account name
# HUB_NAMESPACE = "<hub_name>"

# location of Dockerfiles
DOCKERFILE:="Dockerfile"

CUR_DIR:= $(shell echo "${PWD}")
MKFILE_DIR:=$(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))

##
# Image parameters
SOURCE:= "cuttlefish.dockerfile"
AUTHOR:= sk3l
REPO:=   cuttlefish
IMAGE:=  $(AUTHOR)/$(REPO)
NAME:=   $(REPO)
TAG?=    latest

INSTANCE_NAME?=$(shell echo "cf-$$(date +%Y%m%d-%H%M%S)")

##
# Shared mount config
CF_MOUNT?=
ifeq (${DEBUG}, 1)
    CF_MOUNT=-v "${MKFILE_DIR}:/debug"
endif

##
# Network config
CF_NET_NAME?="cfnet"
CF_NET_CIDR?=192.168.45.0/24
CF_NET_IP?=192.168.45.10
CF_NET_PORT?=8011
CF_NET_PUB?="0.0.0.0:${CF_NET_PORT}:${CF_NET_PORT}"

CONF_NAME:=NEW

# HELP
# This will output the help for each task
# thanks to https://marmelab.com/blog/2016/02/29/auto-documented-makefile.html
.PHONY: help

help: ## This help.
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

.DEFAULT_GOAL := help

# DOCKER TASKS
.PHONY: build
build: ## Build the container image
	@cp -f $(MKFILE_DIR)/stage/conf/squid.conf.$(CONF_NAME)     \
		$(MKFILE_DIR)/stage/conf/squid.conf;                    \
	SQUID_PARAMS="-NYC";                                        \
	if [ $(CONF_NAME) = "connect" ]; then                       \
	    echo "config connect";                                  \
		SQUID_PARAMS"=$$SQUID_PARAMS –enable-storeio=null";     \
		sed -i "s/{{source_ip}}/$(CF_NET_IP)/"                  \
			$(MKFILE_DIR)/stage/conf/squid.conf;                \
		sed -i "s/{{listen_port}}/$(CF_NET_PORT)/"              \
			$(MKFILE_DIR)/stage/conf/squid.conf;                \
	else                                                        \
		echo "config default";                                  \
	fi;                                                         \
	PORT_ARG="--build-arg listen_port=$(CF_NET_PORT)";          \
	SQUID_ARG="--build-arg squid_args=$$SQUID_PARAMS";          \
	echo "Squid parameters = $$SQUID_ARG";                      \
	docker build                                                \
		$$PORT_ARG                                              \
		$$SQUID_ARG                                             \
		--tag $(IMAGE)                                          \
		-f $(SOURCE)                                            \
        .;                                                      \
	rm -f $(MKFILE_DIR)/conf/squid.conf

##
# Target for validating image definition
.PHONY: check
check: ## Verify integrity of image
	@image_hash=$(shell docker images -q $(IMAGE):$(TAG));                                \
	if [ -z "$$image_hash" ]; then                                                        \
		echo "ERROR: couldn't locate image $(IMAGE):$(TAG) (have you run 'make build'?)"; \
		exit 1;                                                                           \
	fi

##
# Target for inspecting image tags
.PHONY: ls
ls: ## List image inventory
	@docker images $(IMAGE)

.PHONY: network
network: ## Setup container network
	@if ! docker network inspect $(CF_NET_NAME) > /dev/null 2>&1; then     \
		echo "Creating Docker network $(CF_NET_NAME)";                     \
		docker network create --subnet=$(CF_NET_CIDR) $(CF_NET_NAME);      \
	fi

.PHONY: create
create: network ## Create the container instance
	@docker create               \
		--name $(INSTANCE_NAME)  \
		--network=$(CF_NET_NAME) \
		--ip=$(CF_NET_IP)        \
		--publish=$(CF_NET_PUB)  \
		$(CF_MOUNT)              \
		${IMAGE}

.PHONY: init
init: build network create

.PHONY: start
start: ## Run container on port configured in `config.env`
	docker start ${INSTANCE_NAME}

.PHONY: stop
stop: ## Stop a running container
	docker stop ${INSTANCE_NAME}

.PHONY: debug
debug: ## Create the container instance
	# Bug in podman
	# https://github.com/containers/podman/issues/3759
	docker run
	    --rm                        \
		--name ${INSTANCE_NAME}-dbg \
		-d                          \
		-t                          \
		--entrypoint=/bin/bash      \
		${BT_DB_MNT}                \
		${IMAGE}

.PHONY: rm
rm: ## Remove a container
	docker rm ${INSTANCE_NAME}

.PHONY: rmi
rmi: ## Remove a container image
	docker rmi ${IMAGE}

.PHONY: destroy
destroy: rm rmi

clean: destroy

## Full versioned release
#
release: build tag publish ## Build and publish image to the container registry

##
# Targets handling execution of 'docker push'
publish: login check publish-latest publish-version ## Publish to container registry

publish-latest: tag-latest ## Publish the `latest` taged container to container registry
	@echo 'Publishing latest to container registry'
	docker push $(IMAGE):latest

publish-version: tag-version ## Publish the `{version}` taged container to container registry
	@echo 'Publishing $(IMAGE):$(TAG) to container registry'
	docker push $(IMAGE):$(TAG)

##
# Targets handling execution of 'docker tag'
tag: tag-latest tag-version ## Generate container tags for the `{version}` ans `latest` tags

.PHONY: tag-latest
tag-latest: check ## Generate container `{version}` tag
	@docker tag $(IMAGE) $(IMAGE):latest
	@echo "Tagged version 'latest'"

.PHONY: tag-version
tag-version: check ## Generate container `latest` tag
	@git_tag=$(shell git describe --tags --always --abbrev=0 | grep -e "[0-9]\+\.[0-9]\+"); \
	if [ -z $$git_tag ]; then \
		echo "ERROR: missing or invalid Git tag (have you run 'git tag'?)"; exit 1; \
	fi; \
	docker tag $(IMAGE) $(IMAGE):$$git_tag; \
	echo "Tagged version $$git_tag"

.PHONY: login
login:
	@docker login
# HELPERS

