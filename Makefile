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

IMAGE_NAME:="$(APP_PREFIX)/$(APP_NAME)"
CONT_NAME:="$(APP_NAME)"

CUR_DIR:= $(shell echo "${PWD}")
MKFILE_DIR:=$(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))

##
# Shared mount config
CF_MOUNT?=
ifeq (${DEBUG}, 1)
    CF_MOUNT=-v "${MKFILE_DIR}:/debug"
endif

# Network config
CF_NET_NAME?="cfnet"
CF_NET_CIDR?=192.168.45.0/24
CF_NET_IP?=192.168.45.10
CF_NET_PORT?=3128
CF_NET_PUB?="0.0.0.0:${CF_NET_PORT}:${CF_NET_PORT}"


CONF_NAME:=default
LISTEN_PORT:=3128

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
	@cp -f $(MKFILE_DIR)/stage/conf/squid.conf.$(CONF_NAME) 	\
		$(MKFILE_DIR)/stage/conf/squid.conf; 					\
	SQUID_PARAMS="-NYC";										\
	if [ $(CONF_NAME) = "connect" ]; then 						\
	    echo "config connect"; 									\
		SQUID_PARAMS"=$$SQUID_PARAMS –enable-storeio=null"; 	\
		sed -i "s/{{source_ip}}/$(CF_NET_IP)/" 					\
			$(MKFILE_DIR)/stage/conf/squid.conf;				\
		sed -i "s/{{listen_port}}/$(CF_NET_PORT)/" 				\
			$(MKFILE_DIR)/stage/conf/squid.conf;				\
	else    													\
		echo "config default";									\
	fi;															\
	PORT_ARG="--build-arg listen_port=$(CF_NET_PORT)"; 			\
	SQUID_ARG="--build-arg squid_args=$$SQUID_PARAMS";          \
	echo "Squid parameters = $$SQUID_ARG";						\
	docker build $$PORT_ARG $$SQUID_ARG --tag $(IMAGE_NAME) .;	\
	rm -f $(MKFILE_DIR)/conf/squid.conf

.PHONY: network
network: ## Setup container network
	@if ! docker network inspect $(CF_NET_NAME) > /dev/null 2>&1; then     \
		echo "Creating Docker network $(CF_NET_NAME)";                     \
		docker network create --subnet=$(CF_NET_CIDR) $(CF_NET_NAME);      \
	fi

.PHONY: create
create: network ## Create the container instance
	docker create                \
		--name $(CONT_NAME)      \
		--network=$(CF_NET_NAME) \
		--ip=$(CF_NET_IP)        \
		--publish=$(CF_NET_PUB)  \
		$(CF_MOUNT)              \
		${IMAGE_NAME}

.PHONY: init
init: build network create

.PHONY: start
start: ## Run container on port configured in `config.env`
	docker start ${CONT_NAME}

.PHONY: stop
stop: ## Stop a running container
	docker stop ${CONT_NAME}

.PHONY: debug
debug: ## Create the container instance
	# Bug in podman
	# https://github.com/containers/podman/issues/3759
	docker run --rm --name ${CONT_NAME}-dbg -d -t --entrypoint=/bin/bash ${BT_DB_MNT} ${IMAGE_NAME}

.PHONY: rm
rm: ## Remove a container
	docker rm ${CONT_NAME}

.PHONY: rmi
rmi: ## Remove a container image
	docker rmi ${IMAGE_NAME}

.PHONY: destroy
destroy: rm rmi

clean: destroy

