# MicroShift Builder Migration Notice

## 📢 Important Update

The MicroShift binary building functionality has been moved from this repository to a dedicated repository for better modularity and maintainability.

## 🔄 Migration Details

### What Was Moved

The following components have been moved to the new `microshift-builder` repository:

- **Workflow**: `.github/workflows/microshift-builder.yaml`
- **Documentation**: 
  - `docs/MICROSHIFT_OPTIMIZATION.md`
  - `docs/MICROSHIFT_SOURCE_BUILD.md`
- **Scripts**:
  - `os/scripts/microshift.sh`
  - `os/scripts/microshift-utils.sh`
  - `os/scripts/check-microshift.sh`
  - `os/scripts/check-microshift-tags.sh`
- **Build Logic**: Dedicated Containerfiles and Makefiles for MicroShift building

### What Remains

This repository (`os-builder`) continues to:

- Build complete edge OS images using **pre-built** MicroShift binaries
- Provide optimized builds via `Containerfile.fedora.optimized`
- Support fallback to source builds via `Containerfile.fedora`
- Manage OS-level configuration and services

## 🚀 New Repository

### microshift-builder

**Repository**: `https://github.com/ramaedge/microshift-builder`

**Purpose**: Dedicated MicroShift binary building and packaging

**Key Features**:
- Automated MicroShift binary builds
- Support for multiple MicroShift versions
- Optimized container images with just the binary
- Weekly automated builds of latest releases
- Manual trigger support for custom versions

## 🔗 How It Works Together

### Integration Flow

```
microshift-builder repository
    ↓ builds and stores
Pre-built MicroShift binaries
    ↓ consumed by
os-builder repository
    ↓ produces
Complete Edge OS images
```

### Benefits

1. **Faster Builds**: OS builds now complete in ~5-8 minutes instead of ~25 minutes
2. **Separation of Concerns**: MicroShift building is independent of OS building
3. **Reusability**: Other projects can use the same MicroShift binaries
4. **Modularity**: Each repository has a focused responsibility

## 📋 Updated Workflow

### For OS Building (This Repository)

```bash
# Optimized build (recommended - uses pre-built MicroShift)
make build-optimized MICROSHIFT_VERSION=release-4.19

# Source build (fallback if pre-built not available)
make build MICROSHIFT_VERSION=release-4.19
```

### For MicroShift Building (New Repository)

```bash
# Clone the new repository
git clone https://github.com/ramaedge/microshift-builder.git
cd microshift-builder

# Build MicroShift binary
make build MICROSHIFT_VERSION=release-4.19

# Check what's available
make check
```

## 🔧 Migration Impact

### For Users

- **No breaking changes** to existing build commands
- **Improved performance** with optimized builds
- **Same functionality** with better organization

### For Developers

- **Clearer separation** of MicroShift vs OS concerns
- **Independent versioning** of MicroShift binaries
- **Easier testing** of different MicroShift versions

## 📚 Updated Documentation

### This Repository (os-builder)

- Focuses on edge OS building and configuration
- References MicroShift Builder for binary building
- Maintains compatibility documentation

### New Repository (microshift-builder)

- Complete MicroShift building documentation
- Version management guides
- Integration examples

## 🤝 Backward Compatibility

### Existing Commands Still Work

```bash
# These commands continue to work unchanged
make build
make build-optimized
make check-microshift
```

### Automatic Fallback

If pre-built MicroShift binaries are not available, builds automatically fall back to building from source using the original method.

## ⚡ Quick Migration Guide

### For Users

1. **No action required** - existing commands continue to work
2. **Optional**: Use the new repository for custom MicroShift builds
3. **Recommended**: Use `make build-optimized` for faster builds

### For Contributors

1. **MicroShift changes**: Submit to `microshift-builder` repository
2. **OS changes**: Continue using this repository
3. **Cross-repository changes**: Coordinate between both repositories

## 📞 Support

### Questions or Issues

- **OS building issues**: Use this repository's issue tracker
- **MicroShift building issues**: Use the microshift-builder repository's issue tracker
- **Integration issues**: Can be reported in either repository

### Documentation

- **OS Building**: Continue using this repository's documentation
- **MicroShift Building**: See the new microshift-builder repository

## 📅 Timeline

- **Migration Date**: [Current Date]
- **Transition Period**: Existing functionality remains unchanged
- **Deprecation**: No deprecation planned - both methods supported

---

This migration improves the development experience while maintaining full backward compatibility. The separation of concerns makes both repositories more focused and maintainable. 