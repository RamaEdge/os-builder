# Building MicroShift from Source

This project builds MicroShift from the OpenShift/MicroShift GitHub repository source code instead of using pre-built RPM packages. This approach provides several advantages:

## Benefits

### Latest Features
- **Cutting-edge capabilities**: Access to the latest MicroShift features and bug fixes before they're released
- **Community contributions**: Include community contributions that haven't made it into official releases yet
- **Development builds**: Use development branches for testing new functionality

### Customization
- **Source-level modifications**: Ability to modify MicroShift source code for specific requirements
- **Custom patches**: Apply custom patches or backports
- **Build-time optimizations**: Optimize compilation for specific architectures or use cases

### Clean Runtime Environment
- **Minimal attack surface**: Final image excludes build tools and development dependencies
- **Smaller image size**: Only runtime dependencies and the MicroShift binary are included
- **Better security**: No Git, Go compiler, or build tools in the production image
- **Faster deployment**: Reduced image size means faster pulls and deployments

### Version Control
- **Specific commits**: Build from exact commit hashes for reproducibility
- **Release branches**: Use specific release branches like `release-4.17` or `release-4.18`
- **Tagged versions**: Build from specific tagged versions like `v4.17.1`

## Configuration Options

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `MICROSHIFT_VERSION` | `main` | Git branch, tag, or commit to build from |
| `MICROSHIFT_REPO` | `https://github.com/openshift/microshift.git` | Repository URL to clone from |

### Build Examples

#### Latest Development Version
```bash
# Build from main branch (default)
make build

# Explicitly specify main branch
make build MICROSHIFT_VERSION=main
```

#### Specific Release Branch
```bash
# Build from 4.17 release branch
make build MICROSHIFT_VERSION=release-4.17

# Build from 4.18 release branch
make build MICROSHIFT_VERSION=release-4.18
```

#### Tagged Releases
```bash
# Build from specific tag
make build MICROSHIFT_VERSION=v4.17.1

# Build from release candidate
make build MICROSHIFT_VERSION=4.18.0-rc.1-202501240630.p0
```

#### Custom Repository
```bash
# Build from a fork or different repository
make build MICROSHIFT_REPO=https://github.com/yourfork/microshift.git

# Build from specific commit
make build MICROSHIFT_VERSION=abc123def456
```

## Build Process

### Multi-Stage Build Architecture
The project uses a multi-stage Docker/Podman build to ensure clean separation between build dependencies and the final runtime image:

#### Stage 1: Build Environment (`microshift-builder`)
- **Base Image**: `golang:1.23` (Debian-based, glibc compatible)
- **Purpose**: Compile MicroShift binary from source
- **Dependencies Installed**:
  - **Git**: For cloning the MicroShift repository
  - **Make**: For building MicroShift
  - **GCC**: C compiler for CGO dependencies
  - **libc6-dev**: Development libraries
  - **Go**: Go 1.23 compiler (included in base image)

#### Stage 2: Runtime Environment (Fedora bootc)
- **Base Image**: `quay.io/fedora/fedora-bootc:42`
- **Purpose**: Final bootable container image
- **MicroShift Integration**: Binary copied from builder stage

### Build Steps

#### 1. Source Code Retrieval (Builder Stage)
```bash
# Shallow clone to minimize download size
git clone --depth 1 --branch ${MICROSHIFT_VERSION} ${MICROSHIFT_REPO}
```

#### 2. Compilation (Builder Stage)
```bash
# Build MicroShift binary
cd microshift && make
```

#### 3. Binary Transfer (Runtime Stage)
```bash
# Copy binary from builder to runtime image
COPY --from=microshift-builder /build/microshift /usr/bin/microshift
chmod +x /usr/bin/microshift
```

#### 4. Service Configuration (Runtime Stage)
Custom systemd service files are installed:
- `microshift.service`: Main MicroShift service
- `microshift-cleanup.service`: Cleanup service for failed shutdowns

## Version Information

Built images include labels with MicroShift source information:

```bash
# Inspect image labels
docker inspect localhost/fedora-edge-os:latest | jq '.[0].Config.Labels'

# Key labels
{
  "microshift.version": "main",
  "microshift.source": "https://github.com/openshift/microshift.git"
}
```

## Troubleshooting

### Build Failures

#### Go Version Issues
```bash
# Error: go.mod requires go >= 1.23.0 (running go 1.22.12)
# Solution: Update to Go 1.23+ for MicroShift 4.19+
FROM golang:1.23 AS microshift-builder
```

#### Binary Compatibility Issues
```bash
# Error: exec /usr/bin/microshift: no such file or directory
# Cause: musl vs glibc incompatibility when using Alpine builder
# Solution: Use glibc-based builder image (golang:1.23 instead of golang:1.23-alpine)
```

#### Build Dependencies Missing
```bash
# Error: cgo: C compiler "gcc" not found
# Error: cannot find 'ld'
# Solution: Install complete build toolchain
RUN apt-get update && apt-get install -y --no-install-recommends \
    git make gcc libc6-dev && rm -rf /var/lib/apt/lists/*
```

#### Network Issues
```bash
# Error: Failed to clone repository
# Solution: Check network connectivity and repository URL
```

#### Make Target Issues
```bash
# Error: Script only runs on Linux (during make generate-config)
# Solution: Use specific build target to avoid code generation
RUN make build  # Instead of just 'make'
```

### Runtime Issues

#### Service Not Starting
```bash
# Check service status
systemctl status microshift

# Check logs
journalctl -u microshift -f

# Verify binary
/usr/bin/microshift version
```

#### Missing Dependencies
```bash
# Ensure CRI-O is running
systemctl status crio

# Check for missing directories
ls -la /var/lib/microshift
```

## Development Workflow

### Testing Development Changes

1. **Fork Repository**:
   ```bash
   # Fork github.com/openshift/microshift to your account
   ```

2. **Build from Fork**:
   ```bash
   make build MICROSHIFT_REPO=https://github.com/yourusername/microshift.git MICROSHIFT_VERSION=your-feature-branch
   ```

3. **Test Changes**:
   ```bash
   make test
   ```

### Continuous Integration

The build process integrates with GitVersion for automatic versioning:

```bash
# Build with automatic version detection
make build

# Example output
Building Fedora bootc container image...
Using container runtime: podman
MicroShift version: main
MicroShift repository: https://github.com/openshift/microshift.git
GitVersion detected: 1.0.1-beta.1
✅ Build completed successfully!
```

## Best Practices

### Production Deployments
- **Use tagged releases**: Avoid `main` branch for production
- **Pin to specific commits**: For maximum reproducibility
- **Test thoroughly**: Validate functionality before deployment

### Development
- **Use feature branches**: Test specific features or fixes
- **Monitor upstream**: Stay updated with upstream changes
- **Document customizations**: Keep track of any local modifications

### Performance
- **Build caching**: Use container layer caching for faster rebuilds
- **Minimal clones**: Use `--depth 1` for faster cloning
- **Clean builds**: Remove source after build to minimize image size

## Integration with CI/CD

### GitHub Actions
The project's GitHub Actions automatically build with different MicroShift versions:

```yaml
strategy:
  matrix:
    microshift-version: ['main', 'release-4.17', 'release-4.18']
    
steps:
- name: Build Image
  run: |
    make build MICROSHIFT_VERSION=${{ matrix.microshift-version }}
```

### Custom Builds
Integrate with your CI/CD pipeline:

```bash
#!/bin/bash
# ci-build.sh
export MICROSHIFT_VERSION=${MICROSHIFT_VERSION:-main}
export IMAGE_TAG=${CI_COMMIT_SHA:-latest}

make build
make test
```

## References

- [MicroShift GitHub Repository](https://github.com/openshift/microshift)
- [MicroShift Development Documentation](https://microshift.io/docs/developer-documentation/)
- [OpenShift Documentation](https://docs.openshift.com/)
- [Kubernetes Documentation](https://kubernetes.io/docs/) 