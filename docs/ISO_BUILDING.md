# ISO Building Guide

This project includes automated ISO building capabilities that create bootable installation media from your container images with customizable user configurations.

## Overview

The ISO building process creates bootable installation media with pre-configured settings:

- User accounts with SSH keys
- Custom hostnames and DNS configuration
- Different levels of automation vs interactivity

## Configuration Types

Four configuration options are available:

### 1. Minimal (`minimal-config.toml`)

Basic pre-configured setup for automated deployment:

```toml
[[customizations.user]]
name = "user"
password = "changeme"  # IMPORTANT: Change this password!
groups = ["wheel"]
```

### 2. User (`user-config.toml`)

Pre-configured users with network settings:

```toml
[[customizations.user]]
name = "admin"
password = "secure-password"
key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC..."
groups = ["wheel", "sudo"]

[customizations.hostname]
hostname = "fedora-edge-builder"

[customizations.dns]
nameservers = ["8.8.8.8", "8.8.4.4"]
```

### 3. Advanced (`advanced-config.toml`)

Guided installation with basic prompts:

```toml
[customizations.installer.kickstart]
path = "/kickstart.ks"
```

### 4. Interactive (`interactive-config.toml`)

Fully interactive installation wizard:

```toml
[customizations.installer.kickstart]
path = "/kickstart-interactive.ks"
```

## Building ISOs

### Via GitHub Actions (Recommended)

ISOs are automatically built when:
- Code is pushed to main branch
- Pull requests are merged
- Manual workflow dispatch

Download ISOs from GitHub Actions artifacts.

### Local Building

```bash
# Build all ISO types
make build-iso-minimal
make build-iso-user
make build-iso-advanced
make build-iso-interactive

# Or build specific type
make build-iso-[type]
```

## Customizing Configuration

To create your own ISO:

1. Copy an example configuration file from `config-examples/`
2. Edit user accounts, passwords, and SSH keys
3. Modify hostname and DNS settings
4. Build the ISO with your configuration

### Example User Configuration

```toml
[[customizations.user]]
name = "your-username"
password = "your-secure-password"
key = "ssh-rsa AAAAB3..."  # Your SSH public key
groups = ["wheel", "sudo"]
```

### Example Network Configuration

```toml
[customizations.hostname]
hostname = "your-hostname"

[customizations.dns]
nameservers = ["8.8.8.8", "1.1.1.1"]
search_domains = ["your.domain"]
```

## Interactive Installation Features

The interactive ISO provides a guided installation with:

- **User Account Setup**: Username, password, SSH key configuration
- **Network Configuration**: DHCP, static IP, or manual setup
- **Filesystem Options**: 
  - Simple: Single root partition (20GB minimum)
  - Standard: Root + home partitions (30GB minimum)
  - Advanced: Multiple partitions (50GB+ minimum)
  - Custom: Manual partitioning
- **Configuration Review**: Confirm all settings before installation

## Security Best Practices

1. **Change Default Passwords**: Always change default passwords in configuration files
2. **Use SSH Keys**: Prefer SSH key authentication over passwords
3. **Secure Storage**: Keep configuration files with secrets secure
4. **Review Configs**: Always review configuration files before building

## Using the ISOs

Once built, ISOs can be:

1. Downloaded from GitHub Actions artifacts
2. Written to USB drives for bare metal installation
3. Used in virtual machines
4. Deployed via PXE boot

### Pre-configured ISOs (minimal, user)

- Unattended installation
- Automatically creates configured user accounts
- Sets hostname and DNS from configuration

### Interactive ISOs (advanced, interactive)

- Boot to installation wizard
- Configure users, network, and filesystem interactively
- Review settings before installation

## Troubleshooting

### Common Issues

1. **Build Failures**: Check TOML syntax in configuration files
2. **SSH Access**: Verify SSH public keys are correctly formatted
3. **User Permissions**: Ensure users are added to appropriate groups
4. **Network Issues**: Validate IP addresses and DNS settings

### Getting Help

- Check GitHub Actions logs for build errors
- Validate TOML files before building
- Test configurations in virtual machines first
