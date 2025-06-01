# Makefile for Fedora bootc container image build

# Configuration
IMAGE_NAME ?= localhost/fedora-edge-os
IMAGE_TAG ?= $(shell \
	if git rev-parse --git-dir >/dev/null 2>&1; then \
		git describe --tags --always --dirty 2>/dev/null || echo "latest"; \
	else \
		echo "latest"; \
	fi)
CONTAINERFILE ?= os/Containerfile.k3s
REGISTRY ?= localhost
MICROSHIFT_VERSION ?= release-4.19

# Configuration for trivy scanning
TRIVY_SEVERITY ?= CRITICAL,HIGH
TRIVY_FORMAT ?= table
TRIVY_OUTPUT_FILE ?= trivy-scan-results.json

# Detect OS and architecture
UNAME_S := $(shell uname -s)
UNAME_M := $(shell uname -m)

# Container runtime selection with user override capability
# Users can set CONTAINER_RUNTIME=podman or CONTAINER_RUNTIME=docker to override
ifndef CONTAINER_RUNTIME
	ifeq ($(UNAME_S),Darwin)
		# On macOS, prefer podman if available, otherwise docker
		ifneq ($(shell command -v podman 2>/dev/null),)
			CONTAINER_RUNTIME := podman
		else ifneq ($(shell command -v docker 2>/dev/null),)
			CONTAINER_RUNTIME := docker
		else
			$(error No container runtime found. Install docker or podman)
		endif
	else
		# On Linux, prefer podman if available, otherwise docker
		ifneq ($(shell command -v podman 2>/dev/null),)
			CONTAINER_RUNTIME := podman
		else ifneq ($(shell command -v docker 2>/dev/null),)
			CONTAINER_RUNTIME := docker
		else
			$(error No container runtime found. Install docker or podman)
		endif
	endif
endif

# Validate the chosen runtime is available
ifeq ($(shell command -v $(CONTAINER_RUNTIME) 2>/dev/null),)
	$(error Container runtime '$(CONTAINER_RUNTIME)' not found. Available: $(shell command -v docker >/dev/null && echo docker) $(shell command -v podman >/dev/null && echo podman))
endif

.PHONY: help build build-microshift test clean push pull info install-deps disk-image scan sbom install-trivy install-syft

# Default target
help:
	@echo "Fedora bootc Container Image Builder"
	@echo ""
	@echo "Core targets:"
	@echo "  build         - Build K3s edge OS image (default)"
	@echo "  build-microshift - Build MicroShift edge OS image"
	@echo "  test          - Test the built image"
	@echo "  scan          - Run trivy security scan via tar export (vuln+secret only)"
	@echo "  sbom          - Generate SBOM (Software Bill of Materials)"
	@echo "  clean         - Clean up images and containers"
	@echo "  push          - Push image to registry"
	@echo "  info          - Show image information"
	@echo ""
	@echo "Setup targets:"
	@echo "  install-deps  - Install build dependencies"
	@echo "  install-trivy - Install trivy security scanner"
	@echo "  install-syft  - Install syft SBOM generator"
	@echo "  disk-image    - Convert to disk image"
	@echo ""
	@echo "Environment:"
	@echo "  IMAGE_NAME        = $(IMAGE_NAME)"
	@echo "  IMAGE_TAG         = $(IMAGE_TAG)"
	@echo "  CONTAINER_RUNTIME = $(CONTAINER_RUNTIME)"
	@echo "  OS/ARCH           = $(UNAME_S)/$(UNAME_M)"
	@echo "  TRIVY_SEVERITY    = $(TRIVY_SEVERITY)"
	@echo "  TRIVY_FORMAT      = $(TRIVY_FORMAT)"
	@echo ""
	@echo "Examples:"
	@echo "  make build                    # Build K3s image"
	@echo "  make build-microshift         # Build MicroShift image"
	@echo "  make build IMAGE_TAG=v1.0.0   # Build with custom tag"
	@echo "  make test                     # Test the image"
	@echo "  make scan                     # Security scan via tar export (vuln+secret only)"
	@echo "  make sbom                     # Generate SBOM from tar export"
	@echo "  make scan TRIVY_SEVERITY=CRITICAL,HIGH,MEDIUM  # Scan with more severities"
	@echo "  make scan TRIVY_FORMAT=json TRIVY_OUTPUT_FILE=scan.json  # JSON output"
	@echo ""
	@echo "Runtime override:"
	@echo "  make build CONTAINER_RUNTIME=docker   # Force Docker"
	@echo "  make build CONTAINER_RUNTIME=podman   # Force Podman"

# Check container runtime and build the image
build:
	@echo "Building Fedora bootc container image (K3s)..."
	@echo "Using: $(CONTAINER_RUNTIME)"
	@chmod +x os/build.sh
	@# Ensure Containerfile path is relative to os/ directory
	@if [ -f "$(CONTAINERFILE)" ]; then \
		CONTAINERFILE_RELATIVE=$$(realpath --relative-to=os "$(CONTAINERFILE)" 2>/dev/null || echo "$$(basename "$(CONTAINERFILE)")"); \
	elif [ -f "os/$(CONTAINERFILE)" ]; then \
		CONTAINERFILE_RELATIVE="$$(basename "$(CONTAINERFILE)")"; \
	else \
		echo "❌ Error: Containerfile not found: $(CONTAINERFILE)"; \
		echo "   Looked in: $(CONTAINERFILE) and os/$(CONTAINERFILE)"; \
		exit 1; \
	fi; \
	cd os && \
	CONTAINER_RUNTIME="$(CONTAINER_RUNTIME)" \
	IMAGE_NAME="$(IMAGE_NAME)" \
	IMAGE_TAG="$(IMAGE_TAG)" \
	CONTAINERFILE="$$CONTAINERFILE_RELATIVE" \
	./build.sh

# Build MicroShift image
build-microshift:
	@echo "Building Fedora bootc container image (MicroShift)..."
	@echo "Using: $(CONTAINER_RUNTIME)"
	@echo "MicroShift version: $(MICROSHIFT_VERSION)"
	@chmod +x os/build.sh
	@# Verify MicroShift Containerfile exists
	@if [ -f "os/Containerfile.fedora.optimized" ]; then \
		cd os && \
		CONTAINER_RUNTIME="$(CONTAINER_RUNTIME)" \
		IMAGE_NAME="$(IMAGE_NAME)" \
		IMAGE_TAG="$(IMAGE_TAG)" \
		CONTAINERFILE="Containerfile.fedora.optimized" \
		MICROSHIFT_VERSION="$(MICROSHIFT_VERSION)" \
		MICROSHIFT_IMAGE_BASE="$(REGISTRY)/$(subst localhost,ramaedge,$(word 1,$(subst /, ,$(IMAGE_NAME))))/microshift-builder" \
		./build.sh; \
	else \
		echo "❌ Error: MicroShift Containerfile not found: os/Containerfile.fedora.optimized"; \
		exit 1; \
	fi

# Test the built image
test:
	@echo "Testing container image..."
	@TEST_IMAGE="$(IMAGE_NAME):$(IMAGE_TAG)"; \
	if ! $(CONTAINER_RUNTIME) inspect $$TEST_IMAGE >/dev/null 2>&1; then \
		echo "Image $$TEST_IMAGE not found, looking for alternatives..."; \
		CLEAN_TAG=$$(echo "$(IMAGE_TAG)" | sed 's/-dirty$$//'); \
		if $(CONTAINER_RUNTIME) inspect $(IMAGE_NAME):$$CLEAN_TAG >/dev/null 2>&1; then \
			TEST_IMAGE="$(IMAGE_NAME):$$CLEAN_TAG"; \
		else \
			TEST_IMAGE=$$($(CONTAINER_RUNTIME) images $(IMAGE_NAME) --format "{{.Repository}}:{{.Tag}}" | head -1); \
			if [ -z "$$TEST_IMAGE" ]; then \
				echo "❌ No $(IMAGE_NAME) images found! Run 'make build' first."; \
				exit 1; \
			fi; \
		fi; \
	fi; \
	echo "🧪 Testing: $$TEST_IMAGE"; \
	$(CONTAINER_RUNTIME) run --rm $$TEST_IMAGE /bin/bash -c "bootc status || true"; \
	$(CONTAINER_RUNTIME) run --rm $$TEST_IMAGE /bin/bash -c "systemctl --version | head -1"; \
	$(CONTAINER_RUNTIME) run --rm $$TEST_IMAGE /bin/bash -c "k3s --version || echo 'K3s not found'"; \
	$(CONTAINER_RUNTIME) run --rm $$TEST_IMAGE /bin/bash -c "/usr/bin/otelcol --version || echo 'OTEL not found'"; \
	$(CONTAINER_RUNTIME) run --rm $$TEST_IMAGE /bin/bash -c "ls -la /etc/rancher/k3s/manifests/ 2>/dev/null || echo 'No K3s manifests'"; \
	echo "✅ Tests completed!"

# Clean up
clean:
	@echo "Cleaning up..."
	-$(CONTAINER_RUNTIME) rmi $(IMAGE_NAME):$(IMAGE_TAG) 2>/dev/null || true
	-$(CONTAINER_RUNTIME) system prune -f

# Push to registry
push:
	@echo "Pushing $(IMAGE_NAME):$(IMAGE_TAG)..."
	$(CONTAINER_RUNTIME) push $(IMAGE_NAME):$(IMAGE_TAG)

# Pull base image
pull:
	@echo "Pulling base image..."
	$(CONTAINER_RUNTIME) pull quay.io/fedora/fedora-bootc:42

# Show image info
info:
	@echo "Image information:"
	@$(CONTAINER_RUNTIME) images $(IMAGE_NAME) --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.Size}}" 2>/dev/null || echo "No images found"

# Install dependencies
install-deps:
	@echo "Installing dependencies for $(UNAME_S)..."
ifeq ($(UNAME_S),Darwin)
	@if command -v brew >/dev/null 2>&1; then \
		brew install --cask docker || echo "Docker may already be installed"; \
		brew install hadolint || echo "hadolint may already be installed"; \
		echo "Note: Start Docker Desktop before building"; \
	else \
		echo "❌ Install Homebrew first: https://brew.sh"; \
		exit 1; \
	fi
else
	@if command -v dnf >/dev/null 2>&1; then \
		sudo dnf install -y podman buildah skopeo; \
	elif command -v apt >/dev/null 2>&1; then \
		sudo apt update && sudo apt install -y podman buildah skopeo; \
	else \
		echo "❌ Unsupported package manager. Install podman manually."; \
		exit 1; \
	fi
endif

# Convert to disk image
disk-image:
	@echo "Converting to disk image..."
	@mkdir -p output
ifeq ($(UNAME_S),Darwin)
	@echo "ℹ️  macOS: Consider using 'make build-iso' instead"
	@echo "   disk-image requires Linux or podman machine"
endif
	$(CONTAINER_RUNTIME) pull quay.io/centos-bootc/bootc-image-builder:latest
	$(CONTAINER_RUNTIME) run --rm --privileged \
		-v $(PWD)/output:/output \
		quay.io/centos-bootc/bootc-image-builder:latest \
		--type qcow2 \
		$(IMAGE_NAME):$(IMAGE_TAG)

# Build ISO (simplified)
build-iso:
	@echo "Building ISO..."
	@mkdir -p iso-output
	$(CONTAINER_RUNTIME) pull quay.io/centos-bootc/bootc-image-builder:latest
	$(CONTAINER_RUNTIME) run --rm --privileged \
		-v $(PWD)/iso-output:/output \
		quay.io/centos-bootc/bootc-image-builder:latest \
		--type iso \
		$(IMAGE_NAME):$(IMAGE_TAG) 

# Run trivy security scan on built image via tar export (fixed: uses proper trivy image command)
scan:
	@echo "🔍 Running trivy security scan on $(IMAGE_NAME):$(IMAGE_TAG) via tar export..."
	@# Check if trivy is installed first
	@if ! command -v trivy >/dev/null 2>&1; then \
		echo "❌ Trivy not found! Installing..."; \
		$(MAKE) install-trivy; \
	fi
	@# Create output directory
	@mkdir -p scan-results
	@# Find the image to scan (flexible tag resolution like test target)
	@SCAN_IMAGE="$(IMAGE_NAME):$(IMAGE_TAG)"; \
	if ! $(CONTAINER_RUNTIME) inspect $$SCAN_IMAGE >/dev/null 2>&1; then \
		echo "Image $$SCAN_IMAGE not found, looking for alternatives..."; \
		CLEAN_TAG=$$(echo "$(IMAGE_TAG)" | sed 's/-dirty$$//'); \
		if $(CONTAINER_RUNTIME) inspect $(IMAGE_NAME):$$CLEAN_TAG >/dev/null 2>&1; then \
			SCAN_IMAGE="$(IMAGE_NAME):$$CLEAN_TAG"; \
		else \
			SCAN_IMAGE=$$($(CONTAINER_RUNTIME) images $(IMAGE_NAME) --format "{{.Repository}}:{{.Tag}}" | head -1); \
			if [ -z "$$SCAN_IMAGE" ]; then \
				echo "❌ No $(IMAGE_NAME) images found! Run 'make build' first."; \
				exit 1; \
			fi; \
		fi; \
	fi; \
	echo "🎯 Scanning: $$SCAN_IMAGE"; \
	TAR_FILE="$$(echo "$$SCAN_IMAGE" | sed 's|[:/]|-|g')-$(IMAGE_TAG).tar"; \
	echo "📦 Exporting image to tar file: $$TAR_FILE..."; \
	$(CONTAINER_RUNTIME) save --output "scan-results/$$TAR_FILE" "$$SCAN_IMAGE"; \
	TAR_SIZE=$$(du -h "scan-results/$$TAR_FILE" | cut -f1); \
	echo "✅ Image exported to tar file: scan-results/$$TAR_FILE ($$TAR_SIZE)"; \
	if [[ "$(TRIVY_FORMAT)" == "table" ]]; then \
		echo "📊 Scanning tar file with table output..."; \
		TRIVY_SKIP_CHECK_UPDATE=true TRIVY_DISABLE_MISCONFIG=true trivy image --config .trivy.yaml --input "scan-results/$$TAR_FILE" --severity $(TRIVY_SEVERITY) --format table --scanners vuln,secret; \
	else \
		echo "📄 Scanning tar file with $(TRIVY_FORMAT) output to scan-results/$(TRIVY_OUTPUT_FILE)..."; \
		TRIVY_SKIP_CHECK_UPDATE=true TRIVY_DISABLE_MISCONFIG=true trivy image --config .trivy.yaml --input "scan-results/$$TAR_FILE" --severity $(TRIVY_SEVERITY) --format $(TRIVY_FORMAT) --output scan-results/$(TRIVY_OUTPUT_FILE) --scanners vuln,secret; \
		echo "✅ Scan results saved to scan-results/$(TRIVY_OUTPUT_FILE)"; \
	fi; \
	echo "🧹 Cleaning up tar file..."; \
	rm -f "scan-results/$$TAR_FILE"; \
	echo "✅ Tar-based security scan completed!"

# Generate SBOM (Software Bill of Materials) from built image via tar export
sbom:
	@echo "📋 Generating SBOM for $(IMAGE_NAME):$(IMAGE_TAG) via tar export..."
	@# Check if syft is installed first
	@if ! command -v syft >/dev/null 2>&1; then \
		echo "❌ Syft not found! Installing..."; \
		$(MAKE) install-syft; \
	fi
	@# Create output directory
	@mkdir -p scan-results
	@# Find the image to scan (flexible tag resolution like test target)
	@SCAN_IMAGE="$(IMAGE_NAME):$(IMAGE_TAG)"; \
	if ! $(CONTAINER_RUNTIME) inspect $$SCAN_IMAGE >/dev/null 2>&1; then \
		echo "Image $$SCAN_IMAGE not found, looking for alternatives..."; \
		CLEAN_TAG=$$(echo "$(IMAGE_TAG)" | sed 's/-dirty$$//'); \
		if $(CONTAINER_RUNTIME) inspect $(IMAGE_NAME):$$CLEAN_TAG >/dev/null 2>&1; then \
			SCAN_IMAGE="$(IMAGE_NAME):$$CLEAN_TAG"; \
		else \
			SCAN_IMAGE=$$($(CONTAINER_RUNTIME) images $(IMAGE_NAME) --format "{{.Repository}}:{{.Tag}}" | head -1); \
			if [ -z "$$SCAN_IMAGE" ]; then \
				echo "❌ No $(IMAGE_NAME) images found! Run 'make build' first."; \
				exit 1; \
			fi; \
		fi; \
	fi; \
	echo "🎯 Generating SBOM for: $$SCAN_IMAGE"; \
	TAR_FILE="$$(echo "$$SCAN_IMAGE" | sed 's|[:/]|-|g')-$(IMAGE_TAG).tar"; \
	echo "📦 Exporting image to tar file: $$TAR_FILE..."; \
	$(CONTAINER_RUNTIME) save --output "scan-results/$$TAR_FILE" "$$SCAN_IMAGE"; \
	TAR_SIZE=$$(du -h "scan-results/$$TAR_FILE" | cut -f1); \
	echo "✅ Image exported to tar file: scan-results/$$TAR_FILE ($$TAR_SIZE)"; \
	echo "📋 Generating SBOM from tar file..."; \
	SBOM_FILE="sbom-$$(echo "$$SCAN_IMAGE" | sed 's|[:/]|-|g')-$(IMAGE_TAG).spdx.json"; \
	syft "scan-results/$$TAR_FILE" -o spdx-json="scan-results/$$SBOM_FILE"; \
	echo "✅ SBOM saved to scan-results/$$SBOM_FILE"; \
	echo "🧹 Cleaning up tar file..."; \
	rm -f "scan-results/$$TAR_FILE"; \
	echo "✅ SBOM generation completed!"

# Install trivy if not available  
install-trivy:
	@echo "📦 Installing trivy..."
ifeq ($(UNAME_S),Darwin)
	@if command -v brew >/dev/null 2>&1; then \
		brew install trivy || echo "Trivy may already be installed"; \
	else \
		echo "❌ Install Homebrew first: https://brew.sh"; \
		exit 1; \
	fi
else
	@if command -v dnf >/dev/null 2>&1; then \
		sudo dnf install -y trivy; \
	elif command -v apt >/dev/null 2>&1; then \
		sudo apt update && sudo apt install -y trivy; \
	elif command -v apk >/dev/null 2>&1; then \
		sudo apk add trivy; \
	else \
		echo "❌ Unsupported package manager. Install trivy manually."; \
		echo "See: https://aquasecurity.github.io/trivy/latest/getting-started/installation/"; \
		exit 1; \
	fi
endif
	@echo "✅ Trivy installation completed!"

# Install syft if not available
install-syft:
	@echo "📦 Installing syft..."
ifeq ($(UNAME_S),Darwin)
	@if command -v brew >/dev/null 2>&1; then \
		brew install syft || echo "Syft may already be installed"; \
	else \
		echo "❌ Install Homebrew first: https://brew.sh"; \
		exit 1; \
	fi
else
	@if command -v dnf >/dev/null 2>&1; then \
		sudo dnf install -y syft; \
	elif command -v apt >/dev/null 2>&1; then \
		sudo apt update && sudo apt install -y syft; \
	elif command -v apk >/dev/null 2>&1; then \
		sudo apk add syft; \
	else \
		echo "❌ Unsupported package manager. Install syft manually."; \
		echo "See: https://github.com/anchore/syft#installation"; \
		exit 1; \
	fi
endif
	@echo "✅ Syft installation completed!" 