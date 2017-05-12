thisdir = $(shell pwd)
parentdir = $(shell dirname ${thisdir})

DOCKER=docker $(DOCKER_CLI_OPTS)
IMGNAME=lede-build-img
DATAVOLMNT=/home/lede/data
CONTAINER_NAME=lede-build
BUILDCONFIG=config.rpi2
BUILDPACKAGES=config.packages
DATAVOL=$(CONTAINER_NAME)-data
LEDE_SOURCE_GIT=source
EXTRA_FEEDS=config.extra_feeds

#Two different docker container states to handle
#1. Run a command in a container, delete afterwards (--rm)
#2. Container to mount a data volume, doesn't need to run
#   In this context, CREATE it, copy a file to the data volume, then RM
#This avoids having to deal with starting and stopping processes to keep
#a container up or maintaining started/stopped state

RUN_DOCKER_CMD=$(DOCKER) run \
	--rm \
	-v $(DATAVOL):$(DATAVOLMNT) \
	--name $(CONTAINER_NAME) \
	$(IMGNAME) \
	bash -c

CREATE_DOCKER_CMD=$(DOCKER) create \
	-v $(DATAVOL):$(DATAVOLMNT) \
	--name $(CONTAINER_NAME) \
	$(IMGNAME)

RM_DOCKER_CMD=$(DOCKER) rm \
	$(CONTAINER_NAME)

#order is important!
#1 - Build docker image
#2 - Get LEDE source
#3 - Install feeds
#4 - Seed/Build config
#5 - Build toolchain
#6 - Build kernel modules, packages, target image
clean-build: image clean-data-volume clone-git install-feeds seed-config build-defconfig build-toolchain build-image copy-image

image:
	$(DOCKER) build -f Dockerfile -t $(IMGNAME) .

clean-data-volume:
	$(DOCKER) volume rm -f $(DATAVOL)

clone-git:
	$(RUN_DOCKER_CMD) "cd $(DATAVOLMNT) && \
	git clone https://github.com/lede-project/$(LEDE_SOURCE_GIT).git"

pull-git:
	$(RUN_DOCKER_CMD) "cd $(DATAVOLMNT)/$(LEDE_SOURCE_GIT) && \
	git pull"

build-config:
	-$(CREATE_DOCKER_CMD)
	cat $(BUILDCONFIG) $(BUILDPACKAGES) > ./tmp_config
	cat ./tmp_config
	$(DOCKER) cp ./tmp_config $(CONTAINER_NAME):$(DATAVOLMNT)/$(LEDE_SOURCE_GIT)/.config
	$(RM_DOCKER_CMD)
	$(RUN_DOCKER_CMD) 'cd $(DATAVOLMNT)/$(LEDE_SOURCE_GIT) && \
	make defconfig && \
	cat .config'
	rm ./tmp_config

install-feeds:
	cat $(EXTRA_FEEDS)
	-$(CREATE_DOCKER_CMD)
	$(DOCKER) cp $(EXTRA_FEEDS) $(CONTAINER_NAME):$(DATAVOLMNT)/$(LEDE_SOURCE_GIT)/extra_feeds.conf
	$(RM_DOCKER_CMD)
	$(RUN_DOCKER_CMD) "cd $(DATAVOLMNT)/$(LEDE_SOURCE_GIT) && \
	rm -rf feeds && \
	rm -f feeds.conf && \
	rm -rf package/feeds && \
	cat feeds.conf.default extra_feeds.conf > feeds.conf && \
	scripts/feeds update && \
	scripts/feeds install -a && \
	scripts/feeds list"

build-toolchain:
	$(RUN_DOCKER_CMD) "cd $(DATAVOLMNT)/$(LEDE_SOURCE_GIT) && \
	make -j8 download V=s && \
	make package/base-files/clean V=s && \
	make -j8 tools/install V=s && \
	make -j8 toolchain/install V=s"

build-image:
	$(RUN_DOCKER_CMD) "cd $(DATAVOLMNT)/$(LEDE_SOURCE_GIT) && \
	make -j8 target/compile V=s 'IGNORE_ERRORS=n m' BUILD_LOG=1 && \
	make -j8 package/compile V=s 'IGNORE_ERRORS=n m' BUILD_LOG=1 && \
	make -j8 package/install V=s && \
	make -j8 package/index V=s && \
	make -j1 target/install V=s"

copy-image:
	-$(CREATE_DOCKER_CMD)
	$(DOCKER) cp $(CONTAINER_NAME):$(DATAVOLMNT)/$(LEDE_SOURCE_GIT)/bin/targets/ ./targets
	$(RM_DOCKER_CMD)
