# ISO Building Guide

This document covers how to build bootable ISO images from the containerized OS.

## Quick Steps

```bash
cd os
make build-iso
```

The command above produces an ISO in the `build/` directory. You can customize the process using the environment variables described in `os/README.md`.
