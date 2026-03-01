# Coding Conventions

**Analysis Date:** 2026-03-01

## Naming Patterns

**Files:**
- Bash scripts: lowercase with hyphens (`build.sh`, `health-check.sh`, `setup-k3s-kubeconfig.sh`)
- Configuration files: lowercase with hyphens (`Containerfile.k3s`, `Containerfile.fedora.optimized`)
- Containerfiles: Named with specific distro/purpose suffix (`Containerfile.k3s`, `Containerfile.fedora.optimized`)
- Makefiles: Capital M `Makefile`
- YAML configs: lowercase with hyphens (`config.yaml`, `otelcol.yaml`)
- Documentation: UPPERCASE.md (`README.md`, `VERSION_MANAGEMENT.md`)

**Functions:**
- Descriptive lowercase with underscores: `build_image()`, `run_common_tests()`, `run_k3s_tests()`, `check_health()`, `cleanup_container()`
- Helper functions use descriptive names: `get_git_metadata()`, `check_service()`, `check_endpoint()`
- Short utility functions: `log()`, `info()`, `error()`

**Variables:**
- Environment variables: UPPERCASE with underscores (`IMAGE_NAME`, `CONTAINER_RUNTIME`, `K3S_VERSION`, `BUILD_DATE`)
- Local variables: lowercase with underscores (`git_commit`, `git_repo_url`, `attempt`, `failures`)
- Loop counters: simple lowercase (`i`, or descriptive like `attempt`)
- Constants in Makefiles: UPPERCASE (`PASSED`, `FAILED`, `TOTAL`)

**Types:**
- Not applicable - primarily shell script codebase

## Code Style

**Formatting:**
- 4-space indentation in shell scripts
- Consistent indentation in Dockerfiles (2-4 spaces)
- Makefile uses tab indentation (required by make syntax)
- YAML uses 2-space indentation

**Linting:**
- No formal linting tool configured (eslint, prettier, shellcheck not found)
- Code follows Bash best practices: proper quoting, safe variable expansion
- Consistent use of printf-style output vs echo for colors

**Shebang:**
- Bash scripts: `#!/bin/bash` (standard)
- Location: First line of all executable scripts

## Error Handling

**Patterns:**
- Strict mode is standard: `set -euo pipefail` used in production scripts
- `set -e`: Used in GitHub Actions test script for immediate exit on error
- `set -u`: Prevents use of unset variables (part of `-euo pipefail`)
- `set -o pipefail`: Ensures pipe failures are caught
- Exception: Test script `.github/actions/test-container/test-container.sh` uses only `set -e`

**Error Functions:**
```bash
# Standard error handling pattern
error() { echo -e "${RED}[ERROR]${NC} $*"; }
info() { echo -e "${GREEN}[INFO]${NC} $*"; }

# Usage in scripts
if ! command -v "$CONTAINER_RUNTIME" >/dev/null 2>&1; then
    error "Container runtime '${CONTAINER_RUNTIME}' not found!"
    exit 1
fi
```

**Exit Codes:**
- 0: Success
- 1: General error/failure
- Exit immediately on error due to `set -e` or `set -euo pipefail`

**Trap Usage:**
- Cleanup handlers use trap: `trap cleanup_container EXIT`
- Ensures resources are cleaned up even on script failure
- Example in `.github/actions/test-container/test-container.sh`

## Logging

**Framework:** No logging library - uses built-in echo and color codes

**Patterns:**
- Echo-based logging with color codes:
  ```bash
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  NC='\033[0m'  # No Color
  ```

- Timestamp logging using `systemd-cat`:
  ```bash
  log() {
      echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | systemd-cat -t k3s-kubeconfig-setup
  }
  ```

- Console output with emoji indicators:
  ```bash
  echo "🔨 Building $(IMAGE_NAME):$(IMAGE_TAG)..."
  echo "🧪 Testing container image..."
  echo "✅ All tests passed!"
  echo "❌ Build failed!"
  ```

**When to Log:**
- Start of major operations: "Starting..." messages
- Completion of operations: "...completed" messages
- Status checks: "Checking...", "Testing..." messages
- Warnings and errors: Use descriptive messages
- Health checks: Success/failure indicators per check

**systemd Integration:**
- Scripts that run as systemd services pipe to systemd-cat for journald logging
- Usage: `systemd-cat -t <service-name>` tags logs with service identifier
- See `setup-k3s-kubeconfig.sh` and `edge-setup.sh` for examples

## Comments

**When to Comment:**
- Function purposes at the top of the file:
  ```bash
  #!/bin/bash
  # Build script for Fedora bootc container image
  ```
- Complex logic or non-obvious decisions:
  ```bash
  # Get repository URL (simplified)
  # Convert SSH to HTTPS if needed
  ```
- Configuration sections:
  ```bash
  # Version configuration (passed from Makefile via environment variables)
  ```
- Important commands with context:
  ```bash
  # Improved architecture detection for aarch64/arm64 compatibility
  ```

**No JSDoc/TSDoc:** Not applicable - shell script codebase with no formal documentation generation

## Function Design

**Size:** Functions typically 10-40 lines, focused on single responsibility
- `build_image()`: ~60 lines (builds container, handles multi-step)
- `run_test()`: ~15 lines (runs single test)
- `check_health()`: ~13 lines (checks one component)

**Parameters:**
- Positional parameters for required inputs: `run_test() { local test_name="$1"; local test_cmd="$2"; }`
- Environment variables for configuration: `IMAGE_NAME`, `CONTAINER_RUNTIME`
- Function expects well-formed inputs; limited validation

**Return Values:**
- Exit code 0 for success, non-zero for failure
- Functions return status via explicit `return 0` / `return 1`
- Successful command output to stdout for use in pipelines
- Example: `$(find_image)` returns image reference string

**String Handling:**
- Quote all variable expansions: `"${IMAGE_NAME}:${IMAGE_TAG}"` (not `$IMAGE_NAME:$IMAGE_TAG`)
- Use double quotes for variable substitution
- Use single quotes for literal strings
- Array handling: `FAILED_TESTS+=("$test_name")` for appending

## Module/Script Design

**Script Organization:**
- Configuration variables at top
- Helper functions defined mid-script
- Main execution in `main()` function or directly at end
- Entry point pattern:
  ```bash
  main() {
      # validation
      # execution
  }

  # Handle special flags (help, etc)
  if [[ "${1:-}" == "-h" ]]; then
      # help text
      exit 0
  fi

  main "$@"
  ```

**Exports:** Scripts use environment variables for configuration
- Passed from parent (Makefile) to child scripts
- Example: Makefile sets `IMAGE_NAME`, `CONTAINER_RUNTIME` for `build.sh`

**Sourcing:** No central utility library - each script is self-contained
- All dependencies and functions defined within script
- Promotes script portability and explicit dependencies

## Makefile Conventions

**Target Naming:**
- Phony targets declared at top: `.PHONY: build test clean`
- Lowercase with hyphens: `build`, `test-k3s`, `build-iso`
- Grouped by category: Build, Test, Security, Deploy

**Variables:**
- Configuration at top of file with defaults
- Using `?=` for overrideable variables: `IMAGE_TAG ?= $(shell git describe --tags...)`
- Using `$(shell ...)` for computed values
- Comments explain purpose of sections

**Function Definitions:**
```makefile
define find_image
$(shell ...)
endef

define ensure_tool
@if ! command -v $(1) >/dev/null 2>&1; then \
    $(MAKE) install-$(1); \
fi
endef
```

**Help Documentation:**
- `help:` target documents all major commands
- Includes examples: `make build IMAGE_TAG=v1.0.0`
- Lists all configuration variables available

## Containerfile Conventions

**ARG Placement:**
- Build args before FROM for base image args
- Additional args after FROM for RUN commands
- Naming: Descriptive uppercase (`K3S_VERSION`, `OTEL_VERSION`, `CNI_VERSION`)

**Metadata Labels:**
- OCI standard labels: `org.opencontainers.image.*`
- Application-specific labels: `k3s.version`, `otel.version`
- Labels reference build args: `--label k3s.version="${K3S_VERSION}"`

**Layer Organization:**
- Cache-friendly ordering: Less-frequently-changed layers first
- Package cache update in separate layer
- Directory structure in cached layer
- Download/install in separate layers for independent caching
- Comments explain cache strategy: "separate layer for better caching"

**Architecture Detection:**
- Consistent pattern for aarch64/arm64/x86_64/amd64 handling
- Maps raw architecture to normalized names
- Used in: K3s binary download, CNI plugin selection
```bash
RAW_ARCH=$(uname -m)
if [ "${RAW_ARCH}" = "aarch64" ] || [ "${RAW_ARCH}" = "arm64" ]; then
    ARCH="arm64"
elif [ "${RAW_ARCH}" = "x86_64" ] || [ "${RAW_ARCH}" = "amd64" ]; then
    ARCH="amd64"
fi
```

## Secret Handling

**Secrets Not in Code:**
- No secrets committed to repository
- `.env` files in `.gitignore`
- Credentials passed via environment variables only
- No hardcoded registry credentials, API keys, or passwords

## Cross-File Consistency

All shell scripts follow these conventions:

1. **Shebang and Comments at Top**
   ```bash
   #!/bin/bash
   # Brief description of script purpose
   ```

2. **Early Exits**
   ```bash
   set -euo pipefail
   ```

3. **Input Validation**
   ```bash
   if [ $# -ne 2 ]; then
       echo "Usage: $0 <arg1> <arg2>"
       exit 1
   fi
   ```

4. **Color-coded Output** (if interactive)
   ```bash
   GREEN='\033[0;32m'
   RED='\033[0;31m'
   NC='\033[0m'
   ```

5. **Helper Functions** (before main logic)
   ```bash
   log() { ... }
   error() { ... }
   check_service() { ... }
   ```

6. **Main Execution** (at end or in main() function)
   ```bash
   main() { ... }
   main "$@"
   ```

---

*Convention analysis: 2026-03-01*
