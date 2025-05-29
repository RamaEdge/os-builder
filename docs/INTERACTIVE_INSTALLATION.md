# Interactive Installation Guide

This guide covers the interactive installation feature for Fedora bootc ISOs, which provides a guided setup wizard during installation.

## Overview

The interactive installation provides a user-friendly wizard that prompts for:

- **User Account**: Username, password, SSH key configuration
- **Network Settings**: DHCP, static IP, or manual configuration  
- **Filesystem Layout**: Choice of predefined layouts or custom partitioning

## Building Interactive ISOs

```bash
# Build interactive ISO (recommended method)
make build-iso-interactive

# Alternative: Build from configuration file
make build-iso CONFIG_FILE=config-examples/interactive-config.toml
```

## Installation Process

### 1. Boot the ISO

When you boot the interactive ISO, you'll see a welcome screen and installation wizard.

### 2. User Account Configuration

The installer prompts for:

- **Username**: 3-32 characters, lowercase, start with letter
- **Password**: Minimum 8 characters with confirmation
- **Groups**: Select from available groups (wheel, docker, podman, etc.)
- **SSH Key**: Optional SSH public key for passwordless access

### 3. Network Configuration

Choose from three options:

#### DHCP (Automatic)
- Automatic IP configuration
- Enter custom hostname (optional)

#### Static IP
- IP address, netmask, gateway
- Primary and secondary DNS servers
- Custom hostname

#### Manual
- Configure during installation

### 4. Filesystem Configuration

Choose from predefined layouts:

| Layout | Partitions | Use Case | Min Size |
|--------|------------|----------|----------|
| Simple | `/` (root only) | Basic installations | 20GB |
| Standard | `/`, `/home` | General purpose | 30GB |
| Advanced | `/`, `/home`, `/var`, `/opt` | Container workloads | 50GB |
| Developer | Multiple partitions | Development environments | 80GB |
| Custom | User-defined | Specialized requirements | Varies |

### 5. Configuration Review

The installer shows a summary of all your choices:
- User account details
- Network configuration
- Filesystem layout

Confirm to proceed with installation.

### 6. Installation

The installation proceeds automatically with your configured settings:

- Disk partitioning
- Base system installation
- Container image deployment
- User account creation
- Network configuration

## After Installation

### First Boot

After installation completes:

1. **Remove the ISO** and reboot
2. **System boots** with your configured settings
3. **Log in** using the username/password or SSH key you configured
4. **Network** is automatically configured based on your choices

### Accessing the System

```bash
# Local login
# Use the username and password you configured

# SSH access (if you configured an SSH key)
ssh your-username@your-configured-hostname-or-ip
```

### Verifying Installation

```bash
# Check bootc status
sudo bootc status

# Check network configuration
ip addr show
systemctl status NetworkManager

# Check user account
id
groups

# Check container runtime
podman --version
systemctl status podman

# Check Kubernetes (K3s)
kubectl get nodes
systemctl status k3s
```

## Troubleshooting

### Common Issues

1. **Boot Issues**: Verify ISO was written correctly to USB/CD
2. **Network Not Working**: Check IP configuration and cable connections
3. **SSH Access Denied**: Verify SSH key format and user configuration
4. **Partition Errors**: Ensure sufficient disk space for selected layout

### Getting Help

- Check installation logs in `/var/log/anaconda/`
- Verify configuration choices during review step
- Test network connectivity after installation
- Validate user permissions and group membership

## Tips

- **Test First**: Try interactive installation in a virtual machine first
- **Backup**: Save your configuration choices for future installations
- **Network**: Have network details ready before starting installation
- **SSH Keys**: Generate SSH keys beforehand for passwordless access
- **Disk Space**: Ensure adequate disk space for your chosen layout
