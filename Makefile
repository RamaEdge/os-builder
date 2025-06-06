# Makefile for Fedora bootc container image build

# =============================================================================
# Configuration
# =============================================================================
IMAGE_NAME ?= harbor.local/ramaedge/os-k3s
IMAGE_TAG ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo "latest")
CONTAINERFILE ?= os/Containerfile.k3s
REGISTRY ?= harbor.local

# Load version configuration from centralized file
K3S_VERSION ?= $(shell grep '^K3S_VERSION=' versions.txt | cut -d'=' -f2)
OTEL_VERSION ?= $(shell grep '^OTEL_VERSION=' versions.txt | cut -d'=' -f2)
MICROSHIFT_VERSION ?= $(shell grep '^MICROSHIFT_VERSION=' versions.txt | cut -d'=' -f2)
FEDORA_VERSION ?= $(shell grep '^FEDORA_VERSION=' versions.txt | cut -d'=' -f2)
BOOTC_VERSION ?= $(shell grep '^BOOTC_VERSION=' versions.txt | cut -d'=' -f2)

# Build metadata
GIT_SHA := $(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")
BUILD_DATE := $(shell date -u +%Y-%m-%dT%H:%M:%SZ)

# Security scanning configuration
TRIVY_SEVERITY ?= CRITICAL,HIGH
TRIVY_FORMAT ?= table
TRIVY_OUTPUT_FILE ?= trivy-scan-results.json

# Platform detection
UNAME_S := $(shell uname -s)
UNAME_M := $(shell uname -m)

# =============================================================================
# Container Runtime Detection (Simplified)
# =============================================================================
CONTAINER_RUNTIME ?= $(shell command -v podman 2>/dev/null || command -v docker 2>/dev/null || echo "")
ifeq ($(CONTAINER_RUNTIME),)
	$(error No container runtime found. Install podman or docker)
endif
CONTAINER_RUNTIME := $(notdir $(CONTAINER_RUNTIME))

# =============================================================================
# Common Variables and Functions
# =============================================================================
SCAN_DIR := scan-results
OUTPUT_DIR := output
ISO_DIR := iso-output

# Trivy environment (centralized)
TRIVY_ENV := TRIVY_SKIP_CHECK_UPDATE=true TRIVY_CLOUD_DISABLE=true TRIVY_SCANNERS=vuln

# Common targets
.PHONY: help build build-microshift test clean push pull info scan sbom
.PHONY: install-deps install-trivy install-syft disk-image build-iso

# =============================================================================
# Help Target (Simplified)
# =============================================================================
help:
	@echo "Fedora bootc Container Image Builder"
	@echo ""
	@echo "Build:      build, build-microshift, test, clean"
	@echo "Security:   scan, sbom"
	@echo "Deploy:     push, pull, disk-image, build-iso"
	@echo "Install:    install-deps, install-trivy, install-syft"
	@echo "Info:       info, help"
	@echo ""
	@echo "Config:     IMAGE_NAME=$(IMAGE_NAME)"
	@echo "            IMAGE_TAG=$(IMAGE_TAG)"
	@echo "            CONTAINER_RUNTIME=$(CONTAINER_RUNTIME)"
	@echo ""
	@echo "Versions:   K3S_VERSION=$(K3S_VERSION)"
	@echo "            OTEL_VERSION=$(OTEL_VERSION)"
	@echo "            MICROSHIFT_VERSION=$(MICROSHIFT_VERSION)"
	@echo "            FEDORA_VERSION=$(FEDORA_VERSION)"
	@echo ""
	@echo "Examples:   make build IMAGE_TAG=v1.0.0"
	@echo "            make scan TRIVY_SEVERITY=CRITICAL,HIGH,MEDIUM"

# =============================================================================
# Internal Helper Functions
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
		echo "📦 Installing $(1)..."; \
		$(MAKE) install-$(1); \
	fi
endef



# =============================================================================
# Build Targets
# =============================================================================
build:
	@echo "🔨 Building $(IMAGE_NAME):$(IMAGE_TAG) with $(CONTAINER_RUNTIME)..."
	@echo "📋 Using versions: K3S=$(K3S_VERSION), OTEL=$(OTEL_VERSION)"
	@chmod +x os/build.sh
	@cd os && \
	CONTAINER_RUNTIME="$(CONTAINER_RUNTIME)" \
	IMAGE_NAME="$(IMAGE_NAME)" \
	IMAGE_TAG="$(IMAGE_TAG)" \
	CONTAINERFILE="$(notdir $(CONTAINERFILE))" \
	K3S_VERSION="$(K3S_VERSION)" \
	OTEL_VERSION="$(OTEL_VERSION)" \
	FEDORA_VERSION="$(FEDORA_VERSION)" \
	BOOTC_VERSION="$(BOOTC_VERSION)" \
	GIT_SHA="$(GIT_SHA)" \
	BUILD_DATE="$(BUILD_DATE)" \
	./build.sh

build-microshift:
	@echo "🔨 Building MicroShift image with $(CONTAINER_RUNTIME)..."
	@echo "📋 Using versions: MicroShift=$(MICROSHIFT_VERSION), Fedora=$(FEDORA_VERSION)"
	@test -f os/Containerfile.fedora.optimized || (echo "❌ Missing MicroShift Containerfile" && exit 1)
	@chmod +x os/build.sh
	@cd os && \
	CONTAINER_RUNTIME="$(CONTAINER_RUNTIME)" \
	IMAGE_NAME="$(IMAGE_NAME)" \
	IMAGE_TAG="$(IMAGE_TAG)" \
	CONTAINERFILE="Containerfile.fedora.optimized" \
	MICROSHIFT_VERSION="$(MICROSHIFT_VERSION)" \
	FEDORA_VERSION="$(FEDORA_VERSION)" \
	BOOTC_VERSION="$(BOOTC_VERSION)" \
	K3S_VERSION="$(K3S_VERSION)" \
	OTEL_VERSION="$(OTEL_VERSION)" \
	GIT_SHA="$(GIT_SHA)" \
	BUILD_DATE="$(BUILD_DATE)" \
	MICROSHIFT_IMAGE_BASE="$(REGISTRY)/ramaedge/microshift-builder" \
	./build.sh

# =============================================================================
# Test and Info Targets
# =============================================================================
test:
	@echo "🧪 Testing container image..."
	@TARGET_IMAGE=$(call find_image); \
	test -n "$$TARGET_IMAGE" || (echo "❌ No image found! Run 'make build' first." && exit 1); \
	echo "Testing: $$TARGET_IMAGE"; \
	$(CONTAINER_RUNTIME) run --rm $$TARGET_IMAGE /bin/bash -c "bootc status || true; systemctl --version | head -1; k3s --version || echo 'K3s not found'"

info:
	@echo "📊 Image information:"
	@$(CONTAINER_RUNTIME) images $(IMAGE_NAME) --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.Size}}" 2>/dev/null || echo "No images found"

# =============================================================================
# Security Targets - Container vulnerability scanning only
# =============================================================================
scan:
	$(call ensure_tool,trivy)
	@echo "🔍 Scanning container image $(IMAGE_NAME):$(IMAGE_TAG)..."
	@TARGET_IMAGE=$(call find_image); \
	test -n "$$TARGET_IMAGE" || (echo "❌ No image found! Run 'make build' first." && exit 1); \
	mkdir -p $(SCAN_DIR); \
	TAR_FILE="$(SCAN_DIR)/$$(echo "$$TARGET_IMAGE" | sed 's|[:/]|-|g')-$$(date +%s).tar"; \
	echo "📦 Exporting $$TARGET_IMAGE to tar..."; \
	$(CONTAINER_RUNTIME) save --output "$$TAR_FILE" "$$TARGET_IMAGE"; \
	if [ "$(TRIVY_FORMAT)" = "table" ]; then \
		$(TRIVY_ENV) trivy image --config .trivy.yaml --input "$$TAR_FILE" --severity $(TRIVY_SEVERITY) --format table; \
	else \
		$(TRIVY_ENV) trivy image --config .trivy.yaml --input "$$TAR_FILE" --severity $(TRIVY_SEVERITY) --format $(TRIVY_FORMAT) --output $(SCAN_DIR)/$(TRIVY_OUTPUT_FILE); \
		echo "✅ Results: $(SCAN_DIR)/$(TRIVY_OUTPUT_FILE)"; \
	fi; \
	rm -f "$$TAR_FILE"

sbom:
	$(call ensure_tool,syft)
	@echo "📋 Generating SBOM for $(IMAGE_NAME):$(IMAGE_TAG)..."
	@TARGET_IMAGE=$(call find_image); \
	test -n "$$TARGET_IMAGE" || (echo "❌ No image found! Run 'make build' first." && exit 1); \
	mkdir -p $(SCAN_DIR); \
	TAR_FILE="$(SCAN_DIR)/$$(echo "$$TARGET_IMAGE" | sed 's|[:/]|-|g')-$$(date +%s).tar"; \
	echo "📦 Exporting $$TARGET_IMAGE to tar..."; \
	$(CONTAINER_RUNTIME) save --output "$$TAR_FILE" "$$TARGET_IMAGE"; \
	SBOM_FILE="$(SCAN_DIR)/sbom-$$(echo "$$TARGET_IMAGE" | sed 's|[:/]|-|g').spdx.json"; \
	syft "$$TAR_FILE" -o spdx-json="$$SBOM_FILE"; \
	echo "✅ SBOM: $$SBOM_FILE"; \
	rm -f "$$TAR_FILE"

# =============================================================================
# Registry Operations
# =============================================================================
push:
	@echo "⬆️  Pushing $(IMAGE_NAME):$(IMAGE_TAG)..."
	@$(CONTAINER_RUNTIME) push $(IMAGE_NAME):$(IMAGE_TAG)

pull:
	@echo "⬇️  Pulling base image..."
	@$(CONTAINER_RUNTIME) pull quay.io/fedora/fedora-bootc:42

clean:
	@echo "🧹 Cleaning up..."
	-@$(CONTAINER_RUNTIME) rmi $(IMAGE_NAME):$(IMAGE_TAG) 2>/dev/null || true
	-@$(CONTAINER_RUNTIME) system prune -f

# =============================================================================
# Image Conversion
# =============================================================================
disk-image:
	@echo "💽 Converting to disk image..."
	@mkdir -p $(OUTPUT_DIR)
	@$(CONTAINER_RUNTIME) pull quay.io/centos-bootc/bootc-image-builder:latest
	@$(CONTAINER_RUNTIME) run --rm --privileged \
		-v $(PWD)/$(OUTPUT_DIR):/output \
		quay.io/centos-bootc/bootc-image-builder:latest \
		--type qcow2 $(IMAGE_NAME):$(IMAGE_TAG)

build-iso:
	@echo "📀 Building ISO..."
	@mkdir -p $(ISO_DIR)
	@$(CONTAINER_RUNTIME) pull quay.io/centos-bootc/bootc-image-builder:latest
	@$(CONTAINER_RUNTIME) run --rm --privileged \
		-v $(PWD)/$(ISO_DIR):/output \
		quay.io/centos-bootc/bootc-image-builder:latest \
		--type iso $(IMAGE_NAME):$(IMAGE_TAG)

# =============================================================================
# Installation Targets (Simplified)
# =============================================================================
install-deps:
	@echo "📦 Installing dependencies..."
ifeq ($(UNAME_S),Darwin)
	@command -v brew >/dev/null || (echo "❌ Install Homebrew first" && exit 1)
	@brew install --cask docker || true
	@brew install hadolint || true
else
	@if command -v dnf >/dev/null 2>&1; then sudo dnf install -y podman buildah skopeo; \
	elif command -v apt >/dev/null 2>&1; then sudo apt update && sudo apt install -y podman buildah skopeo; \
	else echo "❌ Unsupported package manager" && exit 1; fi
endif

install-trivy:
	@echo "📦 Installing trivy..."
ifeq ($(UNAME_S),Darwin)
	@brew install trivy || true
else
	@if command -v dnf >/dev/null 2>&1; then sudo dnf install -y trivy; \
	elif command -v apt >/dev/null 2>&1; then sudo apt update && sudo apt install -y trivy; \
	else echo "❌ Install manually: https://aquasecurity.github.io/trivy/" && exit 1; fi
endif

install-syft:
	@echo "📦 Installing syft..."
ifeq ($(UNAME_S),Darwin)
	@brew install syft || true
else
	@if command -v dnf >/dev/null 2>&1; then sudo dnf install -y syft; \
	elif command -v apt >/dev/null 2>&1; then sudo apt update && sudo apt install -y syft; \
	else echo "❌ Install manually: https://github.com/anchore/syft" && exit 1; fi
endif 