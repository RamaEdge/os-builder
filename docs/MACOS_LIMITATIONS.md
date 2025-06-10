# macOS Limitations and Solutions

Building the OS image on macOS requires running Docker instead of Podman. Some features such as SELinux labeling are not available.

**Workarounds**

1. Use Docker Desktop with virtualization enabled.
2. Run `make build` which detects the platform and adjusts options.
3. For advanced cases, consider building inside a Linux virtual machine.
