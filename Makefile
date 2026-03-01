# Makefile for Fedora bootc container image build

# =============================================================================
# Configuration
# =============================================================================
IMAGE_NAME ?= harbor.local/ramaedge/os-microshift
IMAGE_TAG ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo "latest")
CONTAINERFILE ?= os/Containerfile.microshift
REGISTRY ?= harbor.local

# Load version configuration from versions.json
OTEL_VERSION ?= $(shell jq -r '.components.otel_collector' versions.json)
FEDORA_VERSION ?= $(shell jq -r '.base.fedora' versions.json)
MICROSHIFT_VERSION ?= $(shell jq -r '.components.microshift' versions.json)

# Build metadata
GIT_SHA := $(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")

# Security scanning configuration
TRIVY_SEVERITY ?= CRITICAL,HIGH
TRIVY_FORMAT ?= table
TRIVY_OUTPUT_FILE ?= trivy-scan-results.json

# Platform detection
UNAME_S := $(shell uname -s)

# =============================================================================
# Container Runtime Detection
# =============================================================================
CONTAINER_RUNTIME ?= $(shell command -v podman 2>/dev/null || command -v docker 2>/dev/null || echo "")
ifeq ($(CONTAINER_RUNTIME),)
	$(error No container runtime found. Install podman or docker)
endif
CONTAINER_RUNTIME := $(notdir $(CONTAINER_RUNTIME))

# =============================================================================
# Directories (all build artifacts under .build/)
# =============================================================================
BUILD_DIR := .build
SCAN_DIR := $(BUILD_DIR)/scan-results
OUTPUT_DIR := $(BUILD_DIR)/output
ISO_DIR := $(BUILD_DIR)/iso-output

# Common targets
.PHONY: help build test test-microshift test-bootc test-all clean push pull info
.PHONY: scan sbom install-deps install-trivy install-syft disk-image build-iso

# =============================================================================
# Help
# =============================================================================
help:
	@echo "Fedora bootc Container Image Builder"
	@echo ""
	@echo "Build:      build"
	@echo "Test:       test, test-microshift, test-bootc, test-all"
	@echo "Security:   scan, sbom"
	@echo "Deploy:     push, pull, disk-image, build-iso"
	@echo "Install:    install-deps, install-trivy, install-syft"
	@echo "Info:       info, help, clean"
	@echo ""
	@echo "Config:     IMAGE_NAME=$(IMAGE_NAME)"
	@echo "            IMAGE_TAG=$(IMAGE_TAG)"
	@echo "            CONTAINER_RUNTIME=$(CONTAINER_RUNTIME)"
	@echo ""
	@echo "Versions:   OTEL_VERSION=$(OTEL_VERSION)"
	@echo "            FEDORA_VERSION=$(FEDORA_VERSION)"
	@echo "            MICROSHIFT_VERSION=$(MICROSHIFT_VERSION)"
	@echo ""
	@echo "Examples:   make build IMAGE_TAG=v1.0.0"
	@echo "            make build-iso"

# =============================================================================
# Internal Helpers
# =============================================================================

# Find existing image with fallback logic
define find_image
$(shell \
	if $(CONTAINER_RUNTIME) inspect $(IMAGE_NAME):$(IMAGE_TAG) >/dev/null 2>&1; then \
		echo "$(IMAGE_NAME):$(IMAGE_TAG)"; \
	elif $(CONTAINER_RUNTIME) inspect $(IMAGE_NAME):$(shell echo "$(IMAGE_TAG)" | sed 's/-dirty$$//') >/dev/null 2>&1; then \
		echo "$(IMAGE_NAME):$(shell echo "$(IMAGE_TAG)" | sed 's/-dirty$$//')"; \
	else \
		$(CONTAINER_RUNTIME) images $(IMAGE_NAME) --format "{{.Repository}}:{{.Tag}}" | head -1; \
	fi)
endef

# Check if tool is installed and install if needed
define ensure_tool
	@if ! command -v $(1) >/dev/null 2>&1; then \
		echo "Installing $(1)..."; \
		$(MAKE) install-$(1); \
	fi
endef

# =============================================================================
# Build
# =============================================================================
build:
	@echo "Building $(IMAGE_NAME):$(IMAGE_TAG) with $(CONTAINER_RUNTIME)..."
	@echo "Versions: OTEL=$(OTEL_VERSION), Fedora=$(FEDORA_VERSION), MicroShift=$(MICROSHIFT_VERSION)"
	@chmod +x os/build.sh
	@cd os && \
	CONTAINER_RUNTIME="$(CONTAINER_RUNTIME)" \
	IMAGE_NAME="$(IMAGE_NAME)" \
	IMAGE_TAG="$(IMAGE_TAG)" \
	CONTAINERFILE="Containerfile.microshift" \
	OTEL_VERSION="$(OTEL_VERSION)" \
	FEDORA_VERSION="$(FEDORA_VERSION)" \
	MICROSHIFT_VERSION="$(MICROSHIFT_VERSION)" \
	GIT_SHA="$(GIT_SHA)" \
	./build.sh

# =============================================================================
# Test
# =============================================================================
TEST_TYPE ?= microshift

test:
	@TARGET_IMAGE=$(call find_image); \
	test -n "$$TARGET_IMAGE" || (echo "No image found. Run 'make build' first." && exit 1); \
	echo "Testing: $$TARGET_IMAGE (Type: $(TEST_TYPE))"; \
	chmod +x .github/actions/test-container/test-container.sh; \
	.github/actions/test-container/test-container.sh "$$TARGET_IMAGE" "$(TEST_TYPE)"

test-microshift:
	@$(MAKE) test TEST_TYPE=microshift

test-bootc:
	@$(MAKE) test TEST_TYPE=bootc

test-all:
	@$(MAKE) test-microshift
	@$(MAKE) test-bootc

info:
	@$(CONTAINER_RUNTIME) images $(IMAGE_NAME) --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.Size}}" 2>/dev/null || echo "No images found"

# =============================================================================
# Security Scanning
# =============================================================================
scan:
	$(call ensure_tool,trivy)
	@TARGET_IMAGE=$(call find_image); \
	test -n "$$TARGET_IMAGE" || (echo "No image found. Run 'make build' first." && exit 1); \
	mkdir -p $(SCAN_DIR); \
	echo "Exporting $$TARGET_IMAGE to tar for scanning..."; \
	$(CONTAINER_RUNTIME) save --output $(SCAN_DIR)/scan-image.tar "$$TARGET_IMAGE"; \
	echo "Scanning $$TARGET_IMAGE..."; \
	if [ "$(TRIVY_FORMAT)" = "table" ]; then \
		trivy image --config .trivy.yaml --severity $(TRIVY_SEVERITY) --input $(SCAN_DIR)/scan-image.tar; \
	else \
		trivy image --config .trivy.yaml --severity $(TRIVY_SEVERITY) \
			--format $(TRIVY_FORMAT) --output $(SCAN_DIR)/$(TRIVY_OUTPUT_FILE) --input $(SCAN_DIR)/scan-image.tar; \
		echo "Results: $(SCAN_DIR)/$(TRIVY_OUTPUT_FILE)"; \
	fi; \
	rm -f $(SCAN_DIR)/scan-image.tar

sbom:
	$(call ensure_tool,syft)
	@TARGET_IMAGE=$(call find_image); \
	test -n "$$TARGET_IMAGE" || (echo "No image found. Run 'make build' first." && exit 1); \
	mkdir -p $(SCAN_DIR); \
	echo "Exporting $$TARGET_IMAGE to tar for SBOM..."; \
	$(CONTAINER_RUNTIME) save --output $(SCAN_DIR)/sbom-image.tar "$$TARGET_IMAGE"; \
	echo "Generating SBOM for $$TARGET_IMAGE..."; \
	SBOM_FILE="$(SCAN_DIR)/sbom-$$(echo "$$TARGET_IMAGE" | sed 's|[:/]|-|g').spdx.json"; \
	syft $(SCAN_DIR)/sbom-image.tar -o spdx-json="$$SBOM_FILE"; \
	rm -f $(SCAN_DIR)/sbom-image.tar; \
	echo "SBOM: $$SBOM_FILE"

# =============================================================================
# Registry Operations
# =============================================================================
push:
	@echo "Pushing $(IMAGE_NAME):$(IMAGE_TAG)..."
	@$(CONTAINER_RUNTIME) push $(IMAGE_NAME):$(IMAGE_TAG)

pull:
	@echo "Pulling base image..."
	@$(CONTAINER_RUNTIME) pull quay.io/fedora/fedora-bootc:$(FEDORA_VERSION)

clean:
	@echo "Cleaning build artifacts..."
	-@$(CONTAINER_RUNTIME) rmi $(IMAGE_NAME):$(IMAGE_TAG) 2>/dev/null || true
	-@rm -rf $(BUILD_DIR)

# =============================================================================
# Image Conversion (bootc-image-builder)
# =============================================================================
BIB_IMAGE := quay.io/centos-bootc/bootc-image-builder:latest

disk-image:
	@echo "Converting to disk image..."
	@mkdir -p $(OUTPUT_DIR)
	@$(CONTAINER_RUNTIME) run --rm --privileged \
		-v $(PWD)/$(OUTPUT_DIR):/output \
		$(BIB_IMAGE) \
		--type qcow2 \
		--local \
		$(IMAGE_NAME):$(IMAGE_TAG)

build-iso:
	@echo "Building ISO..."
	@mkdir -p $(ISO_DIR)
	@$(CONTAINER_RUNTIME) run --rm --privileged \
		-v $(PWD)/$(ISO_DIR):/output \
		-v $(PWD)/os/iso-config.toml:/config.toml:ro \
		$(BIB_IMAGE) \
		--type anaconda-iso \
		--config /config.toml \
		--local \
		$(IMAGE_NAME):$(IMAGE_TAG)

# =============================================================================
# Installation (macOS + Linux)
# =============================================================================
install-deps:
	@echo "Installing dependencies..."
ifeq ($(UNAME_S),Darwin)
	@command -v brew >/dev/null || (echo "Install Homebrew first" && exit 1)
	@brew install podman hadolint || true
else
	@if command -v dnf >/dev/null 2>&1; then sudo dnf install -y podman buildah skopeo; \
	elif command -v apt >/dev/null 2>&1; then sudo apt update && sudo apt install -y podman buildah skopeo; \
	else echo "Unsupported package manager" && exit 1; fi
endif

install-trivy:
	@echo "Installing trivy..."
ifeq ($(UNAME_S),Darwin)
	@brew install trivy || true
else
	@if command -v dnf >/dev/null 2>&1; then sudo dnf install -y trivy; \
	elif command -v apt >/dev/null 2>&1; then sudo apt update && sudo apt install -y trivy; \
	else echo "Install manually: https://aquasecurity.github.io/trivy/" && exit 1; fi
endif

install-syft:
	@echo "Installing syft..."
ifeq ($(UNAME_S),Darwin)
	@brew install syft || true
else
	@if command -v dnf >/dev/null 2>&1; then sudo dnf install -y syft; \
	elif command -v apt >/dev/null 2>&1; then sudo apt update && sudo apt install -y syft; \
	else echo "Install manually: https://github.com/anchore/syft" && exit 1; fi
endif
