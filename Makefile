SHELL=/bin/bash -o pipefail

DOCKER ?= docker

COMMIT_NO := $(shell git rev-parse HEAD 2> /dev/null || true)
GIT_COMMIT := $(if $(shell git status --porcelain --untracked-files=no),${COMMIT_NO}-dirty,${COMMIT_NO})
GIT_BRANCH ?= $(shell git rev-parse --abbrev-ref HEAD 2>/dev/null)
GIT_BRANCH_CLEAN := $(shell echo $(GIT_BRANCH) | sed -e "s/[^[:alnum:]]/-/g")

IMAGE_NAME_BUILDER ?= docker.io/falcosecurity/driverkit-builder

IMAGE_NAME_BUILDER_BRANCH := $(IMAGE_NAME_BUILDER):$(GIT_BRANCH_CLEAN)
IMAGE_NAME_BUILDER_COMMIT := $(IMAGE_NAME_BUILDER):$(GIT_COMMIT)
IMAGE_NAME_BUILDER_LATEST := $(IMAGE_NAME_BUILDER):latest

IMAGE_NAME_DRIVERKIT ?= docker.io/falcosecurity/driverkit

IMAGE_NAME_DRIVERKIT_BRANCH := $(IMAGE_NAME_DRIVERKIT):$(GIT_BRANCH_CLEAN)
IMAGE_NAME_DRIVERKIT_COMMIT := $(IMAGE_NAME_DRIVERKIT):$(GIT_COMMIT)
IMAGE_NAME_DRIVERKIT_LATEST := $(IMAGE_NAME_DRIVERKIT):latest

LDFLAGS := -ldflags '-X github.com/falcosecurity/driverkit/pkg/version.buildTime=$(shell date +%s) -X github.com/falcosecurity/driverkit/pkg/version.gitCommit=${GIT_COMMIT} -X github.com/falcosecurity/driverkit/pkg/driverbuilder.builderBaseImage=${IMAGE_NAME_BUILDER_COMMIT}'

driverkit ?= _output/bin/driverkit

.PHONY: build
build: clean ${driverkit}

${driverkit}:
	CGO_ENABLED=0 go build ${LDFLAGS} -o $@ .

.PHONY: clean
clean:
	$(RM) -R _output

image/all: image/builder image/driverkit

.PHONY: image/builder
image/builder:
	$(DOCKER) build \
		-t "$(IMAGE_NAME_BUILDER_BRANCH)" \
		-f build/builder.Dockerfile .
	$(DOCKER) tag $(IMAGE_NAME_BUILDER_BRANCH) $(IMAGE_NAME_BUILDER_COMMIT)
	$(DOCKER) tag "$(IMAGE_NAME_BUILDER_BRANCH)" $(IMAGE_NAME_BUILDER_COMMIT)

.PHONY: image/driverkit
image/driverkit:
	$(DOCKER) build \
		-t "$(IMAGE_NAME_DRIVERKIT_BRANCH)" \
		-f build/driverkit.Dockerfile .
	$(DOCKER) tag $(IMAGE_NAME_DRIVERKIT_BRANCH) $(IMAGE_NAME_DRIVERKIT_COMMIT)
	$(DOCKER) tag "$(IMAGE_NAME_DRIVERKIT_BRANCH)" $(IMAGE_NAME_DRIVERKIT_COMMIT)


.PHONY: push/builder
push/builder:
	$(DOCKER) push $(IMAGE_NAME_BUILDER_BRANCH)
	$(DOCKER) push $(IMAGE_NAME_BUILDER_COMMIT)

.PHONY: push/driverkit
push/driverkit:
	$(DOCKER) push $(IMAGE_NAME_DRIVERKIT_BRANCH)
	$(DOCKER) push $(IMAGE_NAME_DRIVERKIT_COMMIT)

.PHONY: push/latest
push/latest:
	$(DOCKER) tag $(IMAGE_NAME_BUILDER_COMMIT) $(IMAGE_NAME_BUILDER_LATEST)
	$(DOCKER) push $(IMAGE_NAME_BUILDER_LATEST)
	$(DOCKER) tag $(IMAGE_NAME_DRIVERKIT_COMMIT) $(IMAGE_NAME_DRIVERKIT_LATEST)
	$(DOCKER) push $(IMAGE_NAME_DRIVERKIT_LATEST)

.PHONY: test
test:
	go test -v -race ./...
