#
# Copyright (c) 2021 Intel Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# VERSION defines the project version for the bundle.
# Update this value when you upgrade the version of your project.
# To re-generate a bundle for another specific version without changing the standard setup, you can:
# - use the VERSION as arg of the bundle target (e.g make bundle VERSION=2021.2.0)
# - use environment variables to overwrite this value (e.g export VERSION=2021.2.0)
GENERIC_VERSION ?= 2021.2.0
DAY_OF_YEAR ?= $(shell date +%-m%d%H)
VERSION ?= `echo ${GENERIC_VERSION} | sed "s/\(.*\)[0-9])*/\1${DAY_OF_YEAR}/"`-dev-`git rev-parse --short HEAD`

# CHANNELS define the bundle channels used in the bundle.
# Add a new line here if you would like to change its default config. (E.g CHANNELS = "preview,fast,stable")
# To re-generate a bundle for other specific channels without changing the standard setup, you can:
# - use the CHANNELS as arg of the bundle target (e.g make bundle CHANNELS=preview,fast,stable)
# - use environment variables to overwrite this value (e.g export CHANNELS="preview,fast,stable")
ifneq ($(origin CHANNELS), undefined)
BUNDLE_CHANNELS := --channels=$(CHANNELS)
endif

# DEFAULT_CHANNEL defines the default channel used in the bundle.
# Add a new line here if you would like to change its default config. (E.g DEFAULT_CHANNEL = "stable")
# To re-generate a bundle for any other default channel without changing the default setup, you can:
# - use the DEFAULT_CHANNEL as arg of the bundle target (e.g make bundle DEFAULT_CHANNEL=stable)
# - use environment variables to overwrite this value (e.g export DEFAULT_CHANNEL="stable")
ifneq ($(origin DEFAULT_CHANNEL), undefined)
BUNDLE_DEFAULT_CHANNEL := --default-channel=$(DEFAULT_CHANNEL)
endif
BUNDLE_METADATA_OPTS ?= $(BUNDLE_CHANNELS) $(BUNDLE_DEFAULT_CHANNEL)

OC_PROJECT ?= redhat-ods-applications
GENERIC_IMAGE_TAG_BASE ?= registry.connect.redhat.com/intel/aikit-operator
IMAGE_TAG_BASE ?= registry.connect.redhat.com/intel/aikit-operator

# BUNDLE_IMG defines the image:tag used for the bundle.
# You can use it as an arg. (E.g make bundle-build BUNDLE_IMG=<some-registry>/<project-name-bundle>:<tag>)
BUNDLE_IMG ?= $(IMAGE_TAG_BASE)-bundle:v$(VERSION)

# Image URL to use all building/pushing image targets
IMG ?= $(IMAGE_TAG_BASE):$(VERSION)

version: # show version
	@echo ${VERSION}

all: docker-build

##@ General

# The help target prints out all targets with their descriptions organized
# beneath their categories. The categories are represented by '##@' and the
# target descriptions by '##'. The awk commands is responsible for reading the
# entire set of makefiles included in this invocation, looking for lines of the
# file as xyz: ## something, and then pretty-format the target and help. Then,
# if there's a line with ##@ something, that gets pretty-printed as a category.
# More info on the usage of ANSI control characters for terminal formatting:
# https://en.wikipedia.org/wiki/ANSI_escape_code#SGR_parameters
# More info on the awk command:
# http://linuxcommand.org/lc3_adv_awk.php

help: ## Display this help.
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-25s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Build
docker-build: set-vars ## Calls set-vars and then builds the aikit-operator image with the manager.
	docker build --no-cache -t ${IMG} .

docker-push: ## Pushes the aikit-operator image to $(IMG) and then resets OC_PROJECT, IMAGE_TAG_BASE and VERSION to their defaults.
	docker push ${IMG}
	# $(MAKE) set-defaults

OS := $(shell uname -s | tr '[:upper:]' '[:lower:]')
ARCH := $(shell uname -m | sed 's/x86_64/amd64/')

.PHONY: kustomize
KUSTOMIZE = $(shell pwd)/bin/kustomize
kustomize: ## Downloads kustomize locally if necessary and install to $(pwd)/bin.
ifeq (,$(wildcard $(KUSTOMIZE)))
ifeq (,$(shell which kustomize 2>/dev/null))
	@{ \
	set -e ;\
	mkdir -p $(dir $(KUSTOMIZE)) ;\
	echo "Downloading kustomize ..." ;\
	curl -SLo - https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize/v4.3.0/kustomize_v4.3.0_$(OS)_$(ARCH).tar.gz | \
	tar xzf - -C bin/ ;\
	}
else
KUSTOMIZE = $(shell which kustomize)
endif
endif

##@ Prerequisite Commands
.PHONY: helm-operator
HELM_OPERATOR = $(shell pwd)/bin/helm-operator
helm-operator: ## Downloads helm-operator locally if necessary, preferring the $(pwd)/bin path over global if both exist.
ifeq (,$(wildcard $(HELM_OPERATOR)))
ifeq (,$(shell which helm-operator 2>/dev/null))
	@{ \
	set -e ;\
	mkdir -p $(dir $(HELM_OPERATOR)) ;\
	echo "Downloading helm-operator ..." ;\
	curl -SLo $(HELM_OPERATOR) https://github.com/operator-framework/operator-sdk/releases/download/v1.9.2/helm-operator_$(OS)_$(ARCH) ;\
	chmod +x $(HELM_OPERATOR) ;\
	}
else
HELM_OPERATOR = $(shell which helm-operator)
endif
endif

##@ Showing and Setting OC_PROJECT, IMAGE_TAG_BASE and VERSION values. Environment vars will override the defaults.
show-vars: kustomize ## Show OC_PROJECT, IMAGE_TAG_BASE and VERSION values by calling 'kustomize cfg list-setters bundle/ --markdown -R'
	@echo -n 'Showing vars under directory '
	@$(KUSTOMIZE) cfg list-setters bundle --markdown -R || exit 0
	@echo ''
	@echo -n 'Showing vars under directory '
	@$(KUSTOMIZE) cfg list-setters config --markdown -R || exit 0

set-vars: kustomize ## Set OC_PROJECT, IMAGE_TAG_BASE and VERSION values by calling 'kustomize cfg set '. Environment variables will override each var default.
	@$(KUSTOMIZE) cfg set config OC_PROJECT $(OC_PROJECT) -R 1>/dev/null || exit 0
	@$(KUSTOMIZE) cfg set config IMAGE_TAG_BASE $(IMAGE_TAG_BASE) -R 1>/dev/null || exit 0
	@$(KUSTOMIZE) cfg set config VERSION $(VERSION) -R 1>/dev/null || exit 0
	@$(KUSTOMIZE) cfg set bundle OC_PROJECT $(OC_PROJECT) -R 1>/dev/null || exit 0
	@$(KUSTOMIZE) cfg set bundle IMAGE_TAG_BASE $(IMAGE_TAG_BASE) -R 1>/dev/null || exit 0
	@$(KUSTOMIZE) cfg set bundle VERSION $(VERSION) -R 1>/dev/null || exit 0

set-defaults: kustomize ## Sets OC_PROJECT, IMAGE_TAG_BASE and VERSION to their default values
	@unset OC_PROJECT IMAGE_TAG_BASE VERSION && $(MAKE) set-vars
	@$(KUSTOMIZE) cfg set config OC_PROJECT $(OC_PROJECT) -R 1>/dev/null || exit 0
	@$(KUSTOMIZE) cfg set config IMAGE_TAG_BASE $(GENERIC_IMAGE_TAG_BASE) -R 1>/dev/null || exit 0
	@$(KUSTOMIZE) cfg set config VERSION $(GENERIC_VERSION) -R 1>/dev/null || exit 0
	@$(KUSTOMIZE) cfg set bundle OC_PROJECT $(OC_PROJECT) -R 1>/dev/null || exit 0
	@$(KUSTOMIZE) cfg set bundle IMAGE_TAG_BASE $(GENERIC_IMAGE_TAG_BASE) -R 1>/dev/null || exit 0
	@$(KUSTOMIZE) cfg set bundle VERSION $(GENERIC_VERSION) -R 1>/dev/null || exit 0

.PHONY: bundle-build
bundle-build: set-vars ## Calls set-vars and then builds the bundle image $(BUNDLE_IMG).
	docker build --no-cache -f bundle.Dockerfile -t $(BUNDLE_IMG) .

.PHONY: bundle-push
bundle-push: ## Pushes the aikit-operator-bundle image to $(BUNDLE_IMG) and then resets OC_PROJECT, IMAGE_TAG_BASE and VERSION to their defaults.
	$(MAKE) docker-push IMG=$(BUNDLE_IMG)
	# $(MAKE) set-defaults

.PHONY: opm
OPM = ./bin/opm
opm: ## Downloads opm locally if necessary and install to $(pwd)/bin.
ifeq (,$(wildcard $(OPM)))
ifeq (,$(shell which opm 2>/dev/null))
	@{ \
	set -e ;\
	mkdir -p $(dir $(OPM)) ;\
	echo "Downloading opm ..." ;\
	curl -SLo $(OPM) https://github.com/operator-framework/operator-registry/releases/download/v1.18.0/$(OS)-$(ARCH)-opm ;\
	chmod +x $(OPM) ;\
	}
else
OPM = $(shell which opm)
endif
endif

# A comma-separated list of bundle images (e.g. make catalog-build BUNDLE_IMGS=example.com/operator-bundle:v2021.2.0,example.com/operator-bundle:v2021.2.0).
# These images MUST exist in a registry and be pull-able.
BUNDLE_IMGS ?= $(BUNDLE_IMG)

# The image tag given to the resulting catalog image (e.g. make catalog-build CATALOG_IMG=example.com/operator-catalog:v2021.2.0).
CATALOG_IMG ?= $(IMAGE_TAG_BASE)-catalog:v$(VERSION)

# Set CATALOG_BASE_IMG to an existing catalog image tag to add $BUNDLE_IMGS to that image.
ifneq ($(origin CATALOG_BASE_IMG), undefined)
FROM_INDEX_OPT := --from-index $(CATALOG_BASE_IMG)
endif

# Build a catalog image by adding bundle images to an empty catalog using the operator package manager tool, 'opm'.
# This recipe invokes 'opm' in 'semver' bundle add mode. For more information on add modes, see:
# https://github.com/operator-framework/community-operators/blob/7f1438c/docs/packaging-operator.md#updating-your-existing-operator
.PHONY: catalog-build
catalog-build: opm set-vars ## Calls set-vars and then builds the catalog image $(CATALOG_IMG).
	$(OPM) index add --container-tool docker --mode semver --tag $(CATALOG_IMG) --bundles $(BUNDLE_IMGS) $(FROM_INDEX_OPT)

# Push the catalog image.
.PHONY: catalog-push
catalog-push: ## Pushes the aikit-operator-catalog`image to $(CATALOG_IMG) and then resets OC_PROJECT, IMAGE_TAG_BASE and VERSION to their defaults.
	$(MAKE) docker-push IMG=$(CATALOG_IMG)
	# $(MAKE) set-defaults

##@ Deployment
deploy: set-vars ## Calls set-vars and deploys aikit-operator using operator-sdk and OLM
	operator-sdk run bundle -n $(OC_PROJECT) $(IMAGE_TAG_BASE)-bundle:v$(VERSION)
	# $(MAKE) set-defaults

undeploy: set-vars ## Calls set-vars and undeploys aikit-operator deployed by operator-sdk and OLM
	operator-sdk cleanup aikit-operator
	$(MAKE) set-defaults

.PHONY: bundle-validate
bundle-validate:
	@operator-sdk bundle validate ./bundle --select-optional name=operatorhub  --optional-values=k8s-version=1.20  --select-optional suite=operatorframework --optional-values=k8s-version=1.20
