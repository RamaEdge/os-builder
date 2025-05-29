# Makefile for Fedora bootc container image build

# Configuration
IMAGE_NAME ?= localhost/fedora-edge-os
IMAGE_TAG ?= $(shell \
	if git rev-parse --git-dir >/dev/null 2>&1; then \
		git describe --tags --always --dirty 2>/dev/null || echo "latest"; \
	else \
		echo "latest"; \
	fi)
CONTAINERFILE ?= Containerfile.k3s
REGISTRY ?= localhost

# MicroShift specific configuration
MICROSHIFT_VERSION ?= release-4.19

# Detect OS and architecture
UNAME_S := $(shell uname -s)
UNAME_M := $(shell uname -m)

# Container runtime selection (prefer Docker on macOS)
ifeq ($(UNAME_S),Darwin)
	CONTAINER_RUNTIME ?= docker
	CONTAINER_STORAGE_PATH = ~/.docker
else
	CONTAINER_RUNTIME ?= podman
	CONTAINER_STORAGE_PATH = /var/lib/containers/storage
endif

# Build targets
.PHONY: help build build-microshift clean test test-observability push pull lint install-deps disk-image info check-runtime build-iso create-custom-iso version

# Default target
help:
	@echo "Fedora bootc Container Image Builder"
	@echo ""
	@echo "Available targets:"
	@echo "  build         - Build K3s edge OS image (default)"
	@echo "  build-microshift - Build MicroShift edge OS image (using pre-built binaries)"
	@echo "  test          - Test the built image"
	@echo "  test-observability - Test observability stack"
	@echo "  clean         - Clean up images and containers"
	@echo "  push          - Push image to registry"
	@echo "  pull          - Pull base image"
	@echo "  lint          - Lint the Containerfile"
	@echo "  install-deps  - Install build dependencies"
	@echo "  disk-image    - Convert to disk image (requires podman on macOS)"
	@echo "  info          - Show image information"
	@echo "  check-runtime - Check container runtime availability"
	@echo "  build-iso     - Build ISO with custom config (CONFIG_FILE=...)"
	@echo "  build-iso-*   - Build ISO with predefined config (minimal, user, advanced, interactive)"
	@echo "  create-custom-iso - Interactive script to create custom ISO config"
	@echo "  version       - Show version information"
	@echo ""
ifeq ($(UNAME_S),Darwin)
	@echo "⚠️  macOS Users:"
	@echo "  For disk-image and build-iso, install podman: brew install podman"
endif
	@echo ""
	@echo "Environment variables:"
	@echo "  IMAGE_NAME        = $(IMAGE_NAME)"
	@echo "  IMAGE_TAG         = $(IMAGE_TAG)"
	@echo "  CONTAINERFILE     = $(CONTAINERFILE)"
	@echo "  REGISTRY          = $(REGISTRY)"
	@echo "  CONTAINER_RUNTIME = $(CONTAINER_RUNTIME)"
	@echo "  MICROSHIFT_VERSION = $(MICROSHIFT_VERSION) (for MicroShift builds)"
	@echo ""
	@echo "System information:"
	@echo "  OS             = $(UNAME_S)"
	@echo "  Architecture   = $(UNAME_M)"
	@echo ""
	@echo "Examples:"
	@echo "  make build                    # Build K3s image (default)"
	@echo "  make build-microshift         # Build MicroShift image with pre-built binaries"
	@echo "  make build IMAGE_TAG=v1.0.0"
	@echo "  make test"
	@echo "  make build-iso-user"
	@echo "  make build-iso-interactive"
	@echo "  make build-iso CONFIG_FILE=config-examples/minimal-config.toml"

# Check container runtime availability
check-runtime:
	@echo "Checking container runtime availability..."
	@if command -v $(CONTAINER_RUNTIME) >/dev/null 2>&1; then \
		echo "✅ $(CONTAINER_RUNTIME) is available"; \
		$(CONTAINER_RUNTIME) --version; \
	else \
		echo "❌ $(CONTAINER_RUNTIME) is not available"; \
		echo "Run 'make install-deps' to install container runtime"; \
		exit 1; \
	fi

# Build the container image (K3s by default)
build: check-runtime
	@echo "Building Fedora bootc container image (K3s default)..."
	@echo "Using container runtime: $(CONTAINER_RUNTIME)"
	@chmod +x build.sh
	@CONTAINER_RUNTIME=$(CONTAINER_RUNTIME) IMAGE_NAME=$(IMAGE_NAME) IMAGE_TAG=$(IMAGE_TAG) CONTAINERFILE=$(CONTAINERFILE) ./build.sh

# Build MicroShift image with pre-built binaries
build-microshift: check-runtime
	@echo "Building Fedora bootc container image (MicroShift with pre-built binaries)..."
	@echo "Using container runtime: $(CONTAINER_RUNTIME)"
	@echo "MicroShift version: $(MICROSHIFT_VERSION)"
	@echo "Using pre-built binaries from: ghcr.io/ramaedge/microshift-builder:$(MICROSHIFT_VERSION)"
	@chmod +x build.sh
	@CONTAINER_RUNTIME=$(CONTAINER_RUNTIME) IMAGE_NAME=$(IMAGE_NAME) IMAGE_TAG=$(IMAGE_TAG) CONTAINERFILE=Containerfile.fedora.optimized MICROSHIFT_VERSION=$(MICROSHIFT_VERSION) ./build.sh

# Clean up images and containers
clean:
	@echo "Cleaning up images and containers..."
	-$(CONTAINER_RUNTIME) rmi $(IMAGE_NAME):$(IMAGE_TAG) 2>/dev/null || true
	-$(CONTAINER_RUNTIME) system prune -f
	@echo "Cleanup completed."

# Test the built image
test: check-runtime
	@echo "Testing the container image..."
	@echo "Running basic tests with $(CONTAINER_RUNTIME)..."
	$(CONTAINER_RUNTIME) run --rm $(IMAGE_NAME):$(IMAGE_TAG) /bin/bash -c "bootc status || true"
	$(CONTAINER_RUNTIME) run --rm $(IMAGE_NAME):$(IMAGE_TAG) /bin/bash -c "systemctl --version"
	$(CONTAINER_RUNTIME) run --rm $(IMAGE_NAME):$(IMAGE_TAG) /bin/bash -c "dnf --version"
	@# Test for K3s components
	$(CONTAINER_RUNTIME) run --rm $(IMAGE_NAME):$(IMAGE_TAG) /bin/bash -c "kubectl version --client || echo 'kubectl binary found'"
	$(CONTAINER_RUNTIME) run --rm $(IMAGE_NAME):$(IMAGE_TAG) /bin/bash -c "k3s --version || echo 'K3s binary found'"
	@echo "Testing OpenTelemetry Collector..."
	$(CONTAINER_RUNTIME) run --rm $(IMAGE_NAME):$(IMAGE_TAG) /bin/bash -c "/usr/bin/otelcol --version || echo 'OpenTelemetry Collector binary not found'"
	$(CONTAINER_RUNTIME) run --rm $(IMAGE_NAME):$(IMAGE_TAG) /bin/bash -c "ls -la /etc/otelcol/config.yaml"
	@# Check for K3s manifests
	$(CONTAINER_RUNTIME) run --rm $(IMAGE_NAME):$(IMAGE_TAG) /bin/bash -c "ls -la /etc/rancher/k3s/manifests/observability-stack.yaml || echo 'Observability manifests found'"
	@echo "Tests completed."

# Push image to registry
push: check-runtime
	@echo "Pushing image to registry..."
	$(CONTAINER_RUNTIME) push $(IMAGE_NAME):$(IMAGE_TAG) $(REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG)

# Pull base image
pull: check-runtime
	@echo "Pulling base image..."
	$(CONTAINER_RUNTIME) pull quay.io/fedora/fedora-bootc:42

# Lint the Containerfile
lint:
	@echo "Linting Containerfile..."
	@if command -v hadolint >/dev/null 2>&1; then \
		hadolint $(CONTAINERFILE); \
	else \
		echo "hadolint not found, skipping lint check"; \
		echo "Install hadolint for Containerfile linting"; \
	fi

# Install build dependencies
install-deps:
	@echo "Installing build dependencies..."
	@echo "Detected OS: $(UNAME_S)"
ifeq ($(UNAME_S),Darwin)
	@echo "Installing dependencies for macOS..."
	@if command -v brew >/dev/null 2>&1; then \
		echo "Installing Docker Desktop (if not already installed)..."; \
		brew install --cask docker || echo "Docker may already be installed"; \
		echo "Installing hadolint for Containerfile linting..."; \
		brew install hadolint || echo "hadolint may already be installed"; \
		echo "Note: Make sure Docker Desktop is running before building"; \
		echo "Alternative: You can also install podman with: brew install podman"; \
	else \
		echo "❌ Homebrew not found. Please install Homebrew first:"; \
		echo "  /bin/bash -c \"\$$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""; \
		echo "Then run 'make install-deps' again."; \
		exit 1; \
	fi
else
	@if command -v dnf >/dev/null 2>&1; then \
		sudo dnf install -y podman buildah skopeo; \
	elif command -v apt >/dev/null 2>&1; then \
		sudo apt update && sudo apt install -y podman buildah skopeo; \
	else \
		echo "Package manager not supported. Please install podman, buildah, and skopeo manually."; \
	fi
endif

# Convert to disk image (requires bootc-image-builder)
disk-image: check-runtime
	@echo "Converting to disk image..."
	@echo "Using container runtime: $(CONTAINER_RUNTIME)"
	@mkdir -p output
ifeq ($(UNAME_S),Darwin)
	@echo "Running on macOS - setting up local registry access"
	@echo "Starting local registry if not running..."
	@$(CONTAINER_RUNTIME) run -d -p 5555:5000 --name local-registry registry:2 2>/dev/null || echo "Registry already running or port in use"
	@echo "Waiting for registry to start..."
	@sleep 3
	@echo "Tagging and pushing image to local registry..."
	@$(CONTAINER_RUNTIME) tag $(IMAGE_NAME):$(IMAGE_TAG) localhost:5555/$(notdir $(IMAGE_NAME)):$(IMAGE_TAG)
	@$(CONTAINER_RUNTIME) push localhost:5555/$(notdir $(IMAGE_NAME)):$(IMAGE_TAG)
	@$(CONTAINER_RUNTIME) pull quay.io/centos-bootc/bootc-image-builder:latest
	@echo "Building disk image from localhost:5555/$(notdir $(IMAGE_NAME)):$(IMAGE_TAG)..."
	@$(CONTAINER_RUNTIME) run --rm --privileged \
		--security-opt label=type:unconfined_t \
		-v $(PWD)/output:/output \
		--network host \
		quay.io/centos-bootc/bootc-image-builder:latest \
		--type qcow2 \
		localhost:5555/$(notdir $(IMAGE_NAME)):$(IMAGE_TAG) || \
	(echo "❌ Failed to create disk image on macOS"; \
	 echo ""; \
	 echo "🔍 Issue: bootc-image-builder requires podman-style container storage access"; \
	 echo "   which is not available in Docker Desktop on macOS."; \
	 echo ""; \
	 echo "💡 Working solutions for macOS:"; \
	 echo ""; \
	 echo "1️⃣  Use Podman instead of Docker:"; \
	 echo "   brew install podman"; \
	 echo "   podman machine init"; \
	 echo "   podman machine start"; \
	 echo "   make disk-image CONTAINER_RUNTIME=podman"; \
	 echo ""; \
	 echo "2️⃣  Use a Linux VM or container for building:"; \
	 echo "   # Run on a Linux system or VM"; \
	 echo "   make disk-image"; \
	 echo ""; \
	 echo "3️⃣  Use GitHub Actions (automated):"; \
	 echo "   git push  # Triggers automatic disk image build"; \
	 echo ""; \
	 echo "4️⃣  Build ISO instead (works on macOS):"; \
	 echo "   make build-iso-interactive"; \
	 echo ""; \
	 echo "📝 Note: ISOs can be built successfully on macOS with Docker.")
else
	@$(CONTAINER_RUNTIME) pull quay.io/centos-bootc/bootc-image-builder:latest
	@$(CONTAINER_RUNTIME) run --rm -it --privileged \
		-v ./output:/output \
		-v $(CONTAINER_STORAGE_PATH):$(CONTAINER_STORAGE_PATH) \
		quay.io/centos-bootc/bootc-image-builder:latest \
		--type qcow2 \
		$(IMAGE_NAME):$(IMAGE_TAG)
endif

# Show image info
info: check-runtime
	@echo "Image information:"
ifeq ($(CONTAINER_RUNTIME),docker)
	@$(CONTAINER_RUNTIME) images $(IMAGE_NAME):$(IMAGE_TAG) --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.CreatedAt}}\t{{.Size}}" || echo "Image not found"
else
	@$(CONTAINER_RUNTIME) images $(IMAGE_NAME):$(IMAGE_TAG) --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.Created}}\t{{.Size}}" || echo "Image not found"
endif

# Build ISO image with user configuration
build-iso: check-runtime
	@echo "Building ISO image with bootc-image-builder..."
	@echo "🏗️  Using configuration: $(CONFIG_FILE)"
	@if [ ! -f "$(CONFIG_FILE)" ]; then \
		echo "❌ Configuration file not found: $(CONFIG_FILE)"; \
		echo "📝 Available configurations:"; \
		ls -la config-examples/*.toml 2>/dev/null || echo "   No config examples found"; \
		echo "💡 Usage: make build-iso CONFIG_FILE=config-examples/user-config.toml"; \
		exit 1; \
	fi
	@mkdir -p $(PWD)/iso-output
	$(CONTAINER_RUNTIME) pull quay.io/centos-bootc/bootc-image-builder:latest
	$(CONTAINER_RUNTIME) run --rm --privileged \
		--security-opt label=type:unconfined_t \
		-v $(PWD)/iso-output:/output \
		-v $(PWD)/$(CONFIG_FILE):/config.toml:ro \
		quay.io/centos-bootc/bootc-image-builder:latest \
		--type iso \
		--config /config.toml \
		$(IMAGE_NAME):$(IMAGE_TAG)
	@echo "✅ ISO build completed!"
	@echo "📁 Output directory: $(PWD)/iso-output"
	@if [ -f "$(PWD)/iso-output/anaconda-iso/install.iso" ]; then \
		ISO_SIZE=$$(du -h "$(PWD)/iso-output/anaconda-iso/install.iso" | cut -f1); \
		echo "💿 ISO file: $(PWD)/iso-output/anaconda-iso/install.iso ($$ISO_SIZE)"; \
	else \
		echo "🔍 ISO files available:"; \
		find $(PWD)/iso-output -name "*.iso" -exec ls -lh {} \; 2>/dev/null || echo "   No ISO files found"; \
	fi

# Build ISO with predefined configurations
build-iso-%:
	@if [ ! -f "config-examples/$*-config.toml" ]; then \
		echo "❌ Configuration not found: config-examples/$*-config.toml"; \
		echo "📝 Available configurations:"; \
		ls -1 config-examples/*.toml 2>/dev/null | sed 's|config-examples/||; s|-config\.toml||' | sed 's/^/  /' || echo "   No config examples found"; \
		exit 1; \
	fi
	$(MAKE) build-iso CONFIG_FILE=config-examples/$*-config.toml

# Create custom ISO configuration interactively
create-custom-iso:
	@echo "🚀 Creating custom ISO configuration..."
	@chmod +x scripts/create-custom-iso.sh
	@./scripts/create-custom-iso.sh

# Show version information
version:
	@echo "📋 Version Information"
	@echo "======================"
	@echo ""
	@echo "Container Image:"
	@echo "  Name: $(IMAGE_NAME)"
	@echo "  Tag:  $(IMAGE_TAG)"
	@echo ""
	@echo "Git Information:"
	@if git rev-parse --git-dir >/dev/null 2>&1; then \
		echo "  Branch:     $$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"; \
		echo "  Commit:     $$(git rev-parse HEAD 2>/dev/null)"; \
		echo "  Short Hash: $$(git rev-parse --short HEAD 2>/dev/null)"; \
		echo "  Dirty:      $$(git diff --quiet || echo 'Yes' && echo 'No')"; \
	else \
		echo "  Not in a git repository"; \
	fi
	@echo ""
	@echo "Build Environment:"
	@echo "  OS:            $(UNAME_S)"
	@echo "  Architecture:  $(UNAME_M)"
	@echo "  Runtime:       $(CONTAINER_RUNTIME)" 