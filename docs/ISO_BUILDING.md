# ISO Building with User Configuration

This project includes automated ISO building capabilities using `bootc-image-builder` with customizable user configurations. The ISOs are built automatically in GitHub Actions and can be downloaded as artifacts.

## Overview

The ISO building process creates bootable installation media from your container images with pre-configured user settings, hostname, DNS configuration, and other customizations. This allows end users to:

- Add their own user accounts with SSH keys
- Configure custom hostnames  
- Set DNS server preferences
- Customize filesystem layouts (advanced)
- Add kernel arguments (advanced)

## Configuration Files

Four configuration templates are provided in the `config-examples/` directory:

### 1. Minimal Configuration (`minimal-config.toml`)

Pre-configured setup with a single user account for automated deployment:

```toml
[[customizations.user]]
name = "user"
password = "changeme"  # IMPORTANT: Change this password!
groups = ["wheel"]
```

### 2. User Configuration (`user-config.toml`)

Pre-configured users with hostname and DNS settings for automated deployment:

```toml
[[customizations.user]]
name = "admin"
password = "secure-password"
key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC..."
groups = ["wheel", "sudo"]

[customizations.hostname]
hostname = "fedora-edge-builder"

[customizations.dns]
nameservers = ["8.8.8.8", "8.8.4.4", "1.1.1.1"]
search_domains = ["local", "internal"]
```

### 3. Advanced Configuration (`advanced-config.toml`)

Uses Kickstart file for guided installation with kernel arguments:

```toml
[customizations.kernel]
append = "selinux=permissive audit=1 crashkernel=auto"

[customizations.installer.kickstart]
path = "/kickstart.ks"
```

### 4. Interactive Configuration (`interactive-config.toml`)

Provides fully interactive installation with user prompts during ISO boot:

```toml
# All user accounts, network, DNS, and filesystem configuration
# is handled interactively during installation
[customizations.installer.kickstart]
path = "/kickstart-interactive.ks"
```

## Automated ISO Building

ISOs are automatically built in GitHub Actions when:

- Code is pushed to main branches
- Pull requests are merged
- Manual workflow dispatch

Four ISO variants are created:

**Pre-configured ISOs (automated deployment):**

- `minimal` - Basic pre-configured user account
- `user` - Full pre-configured user and network settings

**Interactive ISOs (guided installation):**

- `advanced` - Guided installation with basic Kickstart prompts
- `interactive` - Comprehensive interactive installation wizard

## Customizing Your Configuration

To create your own customized ISO:

1. Copy one of the example configuration files
2. Edit the user accounts, passwords, and SSH keys
3. Modify hostname and DNS settings as needed
4. For advanced users: customize filesystem layout and kernel arguments

### User Configuration Options

```toml
[[customizations.user]]
name = "your-username"           # Username for the account
password = "your-secure-password" # Plain text password (will be hashed)
key = "ssh-rsa AAAAB3..."        # Your SSH public key
groups = ["wheel", "sudo"]       # Groups to add user to
```

### Hostname Configuration

```toml
[customizations.hostname]
hostname = "your-hostname"       # Custom hostname for the system
```

### DNS Configuration

```toml
[customizations.dns]
nameservers = ["8.8.8.8", "1.1.1.1"]    # DNS servers
search_domains = ["your.domain"]          # DNS search domains
```

### Filesystem Customizations (Advanced)

```toml
[[customizations.filesystem]]
mountpoint = "/"
minsize = "10 GiB"

[[customizations.filesystem]]
mountpoint = "/var/data"
minsize = "20 GiB"
```

## Security Considerations

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

These ISOs include unattended installation capabilities and will automatically:

- Install the bootc container image  
- Create pre-configured user accounts
- Set pre-configured hostname and DNS settings
- Use default filesystem layout

### Interactive ISOs (advanced, interactive)

These ISOs provide a guided installation experience:

1. **Boot the ISO** - System boots to installation wizard
2. **User Configuration** - Enter username, password, and SSH key
3. **Network Setup** - Choose DHCP, static IP, or manual configuration
4. **Filesystem Layout** - Select from predefined layouts or manual partitioning
5. **Review Settings** - Confirm configuration before installation
6. **Installation** - Automated installation with your custom settings

#### Interactive Installation Features:

- **User Account Setup**: Username validation, secure password, SSH key configuration
- **Network Configuration**: 
  - DHCP with custom hostname
  - Static IP with gateway, DNS, and hostname
  - Manual configuration during installation
- **Filesystem Options**:
  - Simple: Single root partition (20GB minimum)
  - Standard: Root + home partitions (30GB minimum)  
  - Advanced: Root + home + var + opt (50GB minimum)
  - Developer: Multiple partitions optimized for development (80GB minimum)
  - Custom: Manual partitioning interface
- **IP Address Validation**: Automatic validation of IP addresses and network settings
- **Configuration Summary**: Review all settings before proceeding

## Troubleshooting

### Common Issues

1. **Build Failures**: Check that configuration TOML syntax is valid
2. **Missing Users**: Ensure user configuration is properly formatted
3. **SSH Access**: Verify SSH public keys are correctly formatted
4. **Permissions**: Make sure users are added to appropriate groups

### Debug Information

ISO build logs are available in GitHub Actions, including:

- Configuration file validation
- bootc-image-builder output
- ISO creation status
- File size and location information

## Manual ISO Building

To build ISOs locally:

```bash
# Build container image first
make build

# Option 1: Use Makefile targets (recommended)
make build-iso-user          # Automated user configuration
make build-iso-interactive   # Interactive installation
make build-iso-advanced      # Advanced features with Kickstart

# Option 2: Manual build with custom config
mkdir iso-output
docker run --rm --privileged \
  --security-opt label=type:unconfined_t \
  -v ./config-examples/user-config.toml:/config.toml:ro \
  -v ./iso-output:/output \
  quay.io/centos-bootc/bootc-image-builder:latest \
  --type iso \
  --config /config.toml \
  localhost/fedora-edge-os:latest

# Option 3: Interactive configuration generator
make create-custom-iso       # Creates custom configuration file
make build-iso CONFIG_FILE=custom-config.toml
```

## Additional Resources

- [bootc-image-builder Documentation](https://github.com/osbuild/bootc-image-builder)
- [TOML Configuration Format](https://toml.io/)
- [SSH Key Generation Guide](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent)
- [Fedora bootc Documentation](https://docs.fedoraproject.org/en-US/bootc/)
