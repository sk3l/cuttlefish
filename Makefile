#MAJOR?=0
#MINOR?=1

#VERSION=$(MAJOR).$(MINOR)

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

DOCKER_MNT?=""
ifeq (${DEBUG}, 1)
    DOCKER_MNT=-v "${MKFILE_DIR}:/debug"
endif

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
		sed -i "s/{{source_ip}}/$(SOURCE_IP)/" 					\
			$(MKFILE_DIR)/stage/conf/squid.conf;				\
		sed -i "s/{{listen_port}}/$(LISTEN_PORT)/" 				\
			$(MKFILE_DIR)/stage/conf/squid.conf;				\
	else    													\
		echo "config default";									\
	fi;															\
	PORT_ARG="--build-arg listen_port=$(LISTEN_PORT)"; 			\
	SQUID_ARG="--build-arg squid_params=$$SQUID_PARAMS"; 		\
	docker build $$PORT_ARG $$SQUID_ARG --tag $(IMAGE_NAME) .;	\
	rm -f $(MKFILE_DIR)/conf/squid.conf

.PHONY: create
create: ## Create the container instance
	docker create --name ${CONT_NAME} ${BT_DB_MNT} ${IMAGE_NAME}

.PHONY: init
init: build create

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

