# Interactive Installation Guide

This guide covers the interactive installation feature for Fedora bootc ISOs, which provides a guided setup wizard during installation.

## Overview

The interactive installation feature uses Kickstart technology to provide a user-friendly installation wizard that prompts for:

- **User Account**: Username, password, SSH key configuration
- **Network Settings**: DHCP, static IP, or manual configuration  
- **Filesystem Layout**: Choice of predefined layouts or custom partitioning

**Two Kickstart files are available:**
- `kickstart.ks` - Basic interactive installation with filesystem options (used by advanced-config.toml)
- `kickstart-interactive.ks` - Comprehensive interactive installation with full user/network configuration (used by interactive-config.toml)

## Building Interactive ISOs

### Quick Start

```bash
# Build interactive ISO (recommended method)
make build-iso-interactive

# Alternative: Build from configuration file
make build-iso CONFIG_FILE=config-examples/interactive-config.toml
```

### What Gets Built

The interactive ISO includes:
- Fedora bootc container image with all edge OS components
- Interactive Kickstart configuration
- Installation wizard that runs during boot
- Validation for user inputs (IP addresses, usernames, etc.)

## Installation Process

### 1. Boot the ISO

When you boot the interactive ISO, you'll see:

```
=========================================================
     Fedora bootc Interactive Installation Wizard
=========================================================

Welcome! This installer will guide you through setting up
your Fedora bootc edge system with your custom configuration.

Press Enter to continue...
```

### 2. User Account Configuration

```
=========================================
USER ACCOUNT CONFIGURATION
=========================================

Enter username (3-32 chars, lowercase, start with letter): admin
Enter password for admin: [hidden]
Confirm password: [hidden]

Additional groups for admin (space-separated, or press Enter for default 'wheel'):
Available groups: wheel docker podman systemd-journal
Groups: wheel docker

Enter SSH public key for admin (optional, press Enter to skip):
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC... user@example.com
```

**Features:**
- Username validation (3-32 characters, lowercase, start with letter)
- Password confirmation (minimum 8 characters)
- Group selection from predefined options
- Optional SSH public key for passwordless access

### 3. Network Configuration

```
=========================================
NETWORK CONFIGURATION
=========================================

Network Configuration Options:
1) DHCP (Automatic IP configuration)
2) Static IP configuration
3) Manual configuration during installation

Select network configuration (1-3): 2
```

#### Option 1: DHCP Configuration
```
Enter hostname (or press Enter for 'fedora-bootc'): my-edge-device
```

#### Option 2: Static IP Configuration
```
Static IP Configuration:
Enter IP address (e.g., 192.168.1.100): 192.168.1.50
Enter netmask (e.g., 255.255.255.0): 255.255.255.0
Enter gateway (e.g., 192.168.1.1): 192.168.1.1
Enter primary DNS server (e.g., 8.8.8.8): 192.168.1.1
Enter secondary DNS server (optional, press Enter to skip): 8.8.8.8
Enter hostname: edge-device-01
```

**Features:**
- IP address validation
- Automatic format checking for all network parameters
- Optional secondary DNS server
- Custom hostname configuration

### 4. Filesystem Configuration

```
=========================================
FILESYSTEM CONFIGURATION
=========================================

Choose your disk partitioning layout:

1) Simple Layout (Recommended for most users)
   - Single root partition with XFS
   - Minimum 20GB recommended

2) Standard Layout
   - Separate /home partition
   - Root partition with XFS
   - Minimum 30GB recommended

3) Advanced Layout
   - Separate /home, /var, /opt partitions
   - Optimized for container workloads
   - Minimum 50GB recommended

4) Developer Layout
   - Multiple partitions for development
   - Extra space for containers and builds
   - Minimum 80GB recommended

5) Custom Layout
   - Manual partitioning during installation

Enter your choice (1-5): 3
```

#### Filesystem Layout Options

| Layout | Partitions | Use Case | Min Size |
|--------|------------|----------|----------|
| Simple | `/` (root only) | Basic installations, testing | 20GB |
| Standard | `/`, `/home` | General purpose workstations | 30GB |
| Advanced | `/`, `/home`, `/var`, `/opt` | Container workloads, servers | 50GB |
| Developer | `/`, `/home`, `/var`, `/opt`, `/usr/local` | Development environments | 80GB |
| Custom | User-defined | Specialized requirements | Varies |

### 5. Configuration Review

```
=========================================
INSTALLATION CONFIGURATION SUMMARY
=========================================

User Account:
  Username: admin
  Groups: wheel docker
  SSH Key: ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC...

Network Configuration:
  Type: Static IP
  IP Address: 192.168.1.50
  Netmask: 255.255.255.0
  Gateway: 192.168.1.1
  DNS: 192.168.1.1 8.8.8.8
  Hostname: edge-device-01

Filesystem Layout:
  Type: Advanced (root + home + var + opt)

=========================================

Proceed with installation? (y/n): y
```

### 6. Installation Process

The installation proceeds automatically with your configured settings:
- Disk partitioning
- Base system installation
- Container image deployment
- User account creation
- Network configuration
- Service enablement

## Post-Installation

After installation completes, the system will:

1. **Reboot automatically** with your custom configuration
2. **Display welcome message** with system information:

```
=========================================================
Welcome to Fedora bootc Edge OS
=========================================================

System Configuration:
- User: admin (groups: wheel docker)
- Hostname: edge-device-01
- Installation: Interactive Kickstart
- Container Runtime: Podman
- Kubernetes: MicroShift (available)

Quick Start Commands:
- Check bootc status: bootc status
- List containers: podman ps -a
- Enable MicroShift: sudo systemctl enable --now microshift
- Set KUBECONFIG: export KUBECONFIG=/var/lib/microshift/resources/kubeadmin/kubeconfig

Network Configuration:
inet 192.168.1.50/24 brd 192.168.1.255 scope global eth0

=========================================================
```

3. **Enable essential services** automatically:
   - SSH daemon for remote access
   - Container runtime (Podman)
   - Network management
   - Time synchronization

## Advanced Features

### Input Validation

The interactive installer includes comprehensive validation:

- **IP Addresses**: Validates format and ranges (0-255 for each octet)
- **Usernames**: Enforces Linux username conventions
- **Passwords**: Requires minimum length and confirmation
- **Network Settings**: Checks netmask and gateway consistency

### Error Handling

If invalid input is provided:
```
Invalid IP address format.
Enter IP address (e.g., 192.168.1.100): 
```

The installer will prompt again until valid input is provided.

### Cancellation

You can cancel the installation at any time by pressing `Ctrl+C`:
```
Installation cancelled.
```

## Troubleshooting

### Common Issues

**Problem**: Installation hangs at network configuration
**Solution**: Ensure network interface is connected and configured properly

**Problem**: Disk space warnings during partition selection
**Solution**: Choose a layout appropriate for your disk size, or select custom partitioning

**Problem**: SSH key not working after installation
**Solution**: Verify SSH key format (should start with `ssh-rsa`, `ssh-ed25519`, or `ssh-ecdsa`)

### Debug Information

During installation, detailed logs are available:
- Press `Ctrl+Alt+F2` to access a debug console
- Check `/tmp/anaconda.log` for installation details
- Network configuration logs in `/tmp/network-*`

## Customization

### Modifying the Installation Wizard

The interactive installation is controlled by these files:

- `kickstart.ks` - Basic interactive Kickstart (filesystem selection only)
- `kickstart-interactive.ks` - Full interactive Kickstart (user, network, filesystem)
- `config-examples/interactive-config.toml` - References kickstart-interactive.ks
- `config-examples/advanced-config.toml` - References kickstart.ks
- `scripts/create-custom-iso.sh` - Configuration generator script

**Note:** User accounts, network settings, DNS, and filesystem configurations are handled entirely within the Kickstart files, not in the TOML configuration files.

### Adding Custom Validation

To add custom validation for user input:

1. Edit the validation functions in `kickstart-interactive.ks`
2. Add new input prompts in the appropriate section
3. Update the configuration summary display

### Custom Filesystem Layouts

To add new filesystem layout options:

1. Add new case in the filesystem configuration section
2. Create corresponding partition layout in the case statement
3. Update the help text and documentation

## Security Considerations

- **Passwords**: Use strong passwords (minimum 8 characters recommended)
- **SSH Keys**: Prefer SSH key authentication over passwords
- **Network**: Configure firewall appropriately for your environment
- **Users**: Limit sudo access to necessary users only

The interactive installer automatically:
- Locks the root account
- Enables SELinux in enforcing mode
- Configures firewall with SSH access
- Sets secure defaults for all services

## Examples

### Home Lab Setup
```
Username: homelab
Groups: wheel docker
Network: DHCP with hostname "homelab-edge"
Filesystem: Standard layout (30GB minimum)
```

### Production Edge Device
```
Username: operator
Groups: wheel
Network: Static IP with company DNS
Filesystem: Advanced layout (50GB minimum)
SSH Key: Required for secure access
```

### Development Environment
```
Username: developer
Groups: wheel docker podman systemd-journal
Network: DHCP or static as needed
Filesystem: Developer layout (80GB minimum)
SSH Key: For remote development access
``` 