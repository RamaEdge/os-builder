# ISO Building Guide

This project includes automated ISO building capabilities that create bootable installation media with an interactive installer for both K3s and MicroShift distributions.

## Overview

The ISO building process creates a single bootable installation medium with an interactive installer that allows users to choose their configuration during installation:

- **Distribution Selection**: Choose between K3s (lightweight) or MicroShift (enterprise)
- **User Account Creation**: Configure username and password during installation
- **Partitioning Options**: Multiple filesystem layout choices
- **Network Configuration**: Automatic hostname assignment based on distribution choice

## Interactive Installation Flow

When you boot the ISO, the installer guides you through:

### 1. Distribution Selection
```
🚀 Kubernetes Distribution Selection
Choose your Kubernetes distribution:

1) K3s (Recommended)
   - Lightweight Kubernetes
   - Fast startup, minimal resources
   - Great for edge/IoT deployments

2) MicroShift
   - OpenShift-based edge Kubernetes
   - Enterprise features
   - Red Hat ecosystem integration
```

### 2. User Account Setup
- Interactive username creation with validation
- Password setup with confirmation
- Automatic addition to wheel group for sudo access

### 3. Partitioning Options
- **Simple Layout**: Single root partition (recommended)
- **Advanced Layout**: Separate /home and /var partitions
- **Developer Layout**: Separate /home, /var, /opt partitions
- **Custom Layout**: Manual partitioning

## Building the ISO

### Single Command
```bash
# Build interactive ISO for both K3s and MicroShift
make build-iso
```

This creates a single ISO that supports both distributions, with the user choosing during installation.

### Via GitHub Actions (Automated)
ISOs are automatically built when:
- Code is pushed to main branch
- Pull requests are merged
- Manual workflow dispatch

Download ISOs from GitHub Actions artifacts.

## What Happens During Installation

1. **Base Installation**: Installs Fedora bootc base system
2. **User Configuration**: Creates user account with chosen credentials
3. **Distribution Setup**: Based on user choice:
   - **K3s**: Switches to `ghcr.io/ramaedge/os-builder:latest`
   - **MicroShift**: Switches to `ghcr.io/ramaedge/os-builder:microshift-latest`
4. **System Configuration**: 
   - Sets appropriate hostname (`fedora-k3s` or `fedora-microshift`)
   - Configures services and security
   - Creates welcome message with distribution-specific instructions

## Advanced Options

### Custom Container Image
You can specify a custom container image via kernel parameter:
```bash
# At boot, press 'e' to edit grub and add:
bootc.image=your.registry.com/your-image:tag
```

### Security Features
- SELinux enforcing mode
- Firewall enabled with SSH access
- Root account locked (sudo-only access)
- Hardened file permissions
- Secure kernel parameters

## Using the ISO

Once built, the ISO can be:

1. **Downloaded** from GitHub Actions artifacts
2. **Written to USB drives** for bare metal installation:
   ```bash
   dd if=install.iso of=/dev/sdX bs=4M status=progress
   ```
3. **Used in virtual machines** (VMware, VirtualBox, KVM)
4. **Deployed via PXE boot** for network installation

## Post-Installation

After installation, the system provides:

### K3s Distribution
- Service: `systemctl status k3s`
- Kubeconfig: `/etc/rancher/k3s/k3s.yaml`
- Start K3s: `sudo systemctl enable --now k3s`

### MicroShift Distribution  
- Service: `systemctl status microshift`
- Kubeconfig: `/var/lib/microshift/resources/kubeadmin/kubeconfig`
- Start MicroShift: `sudo systemctl enable --now microshift`

## Troubleshooting

### Common Issues

1. **Boot Issues**: Verify ISO integrity and boot media
2. **Network Problems**: Check DHCP availability during installation
3. **Container Pull Failures**: Ensure internet connectivity for bootc switch
4. **Permission Issues**: Default user is added to wheel group for sudo

### Getting Help

- Check GitHub Actions logs for build errors
- Test ISOs in virtual machines first
- Review installation logs in `/var/log/anaconda/`

## Technical Details

- **Base Image**: `quay.io/fedora/fedora-bootc:42`
- **Kickstart File**: `os/kickstart.ks` (unified for both distributions)
- **Builder**: `quay.io/centos-bootc/bootc-image-builder:latest`
- **Installation Method**: Interactive kickstart with bootc switch
