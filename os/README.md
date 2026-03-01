# Fedora bootc Edge OS

Fedora 43 bootc container image with MicroShift for edge computing.

## Contents

```
os/
├── Containerfile.microshift   # Main Containerfile (Fedora 43 bootc base)
├── build.sh                   # Build script with registry auth secret support
├── configs/
│   ├── containers/            # Container runtime configuration (registries.conf)
│   ├── microshift/            # MicroShift configuration
│   ├── otelcol/               # OpenTelemetry Collector configuration
│   └── edgeworks-images.txt   # Generated from versions.json at build time
├── manifests/
│   └── manifests.d/           # Auto-deployed Kubernetes manifests
├── scripts/
│   ├── embed-microshift-images.sh  # Offline image embedding (build-time)
│   └── health-check.sh             # System health check
├── systemd/
│   └── otelcol.service        # OpenTelemetry Collector systemd unit
├── kickstart.ks               # Anaconda kickstart for ISO installation
└── iso-config.toml            # bootc-image-builder configuration
```

## Building

```bash
# From repo root
make build

# Or directly
cd os && ./build.sh
```

The build script automatically:
- Reads versions from `../versions.json`
- Generates the embedded image list from versions.json
- Passes registry auth as a build secret (never baked into the image)

## What Gets Built

The Containerfile produces a bootc-compatible image with:

1. **MicroShift** - Installed from upstream GitHub release RPMs
2. **OpenTelemetry Collector** - Binary from upstream releases
3. **Configuration files** - Container, MicroShift, OTel configs
4. **Embedded container images** - Pre-pulled for offline/air-gapped operation
5. **Systemd services** - SSH, chronyd, CRI-O, MicroShift, OTel all enabled

## ISO Installation

The `kickstart.ks` provides an interactive Anaconda installer that prompts for:
- User credentials
- Hostname and network configuration
- Disk partitioning
- Optional TPM configuration

Build an ISO: `make build-iso`

## Deployed Services

| Service | Port | Description |
|---------|------|-------------|
| SSH | 22 | Remote access |
| MicroShift API | 6443 | Kubernetes API server |
| OTLP gRPC | 4317 | OpenTelemetry telemetry ingestion |
| OTLP HTTP | 4318 | OpenTelemetry telemetry ingestion |

## Updates

```bash
sudo bootc status    # Check current image
sudo bootc upgrade   # Update to latest image
sudo bootc rollback  # Rollback if needed
```
