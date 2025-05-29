# Interactive Kickstart Configuration for Fedora bootc
# This kickstart file provides interactive installation with user customization options

# Use text mode installation but allow interaction
text

# Language and keyboard
lang en_US.UTF-8
keyboard us

# Network configuration - configured during installation
%include /tmp/network-include

# Time zone (can be changed during installation)
timezone --utc America/New_York

# Interactive user creation - configured during installation
# User details will be prompted during installation process
%include /tmp/user-include

# Root password (disabled for security)
rootpw --lock

# Security and authentication
authselect select sssd
selinux --enforcing

# Services
services --enabled=sshd,chronyd,systemd-networkd,systemd-resolved
services --disabled=kdump

# Firewall
firewall --enabled --ssh

# Interactive partitioning
# This provides a menu for users to customize their disk layout
%include /tmp/part-include

# Pre-installation script to create interactive partitioning menu
%pre --interpreter=/bin/bash
#!/bin/bash

# Create interactive partitioning configuration
cat > /tmp/part-include << 'EOF'
# Clear all partitions
clearpart --all --initlabel --disklabel=gpt

# Create boot partitions
reqpart --add-boot

# Default layout if no interaction
part / --grow --fstype=xfs --label=root
EOF

# Interactive user configuration
clear
echo "==================================="
echo "Fedora bootc Interactive Installer"
echo "==================================="
echo ""

# Distribution selection
echo "🚀 Kubernetes Distribution Selection"
echo "-------------------------------------"
echo ""
echo "Choose your Kubernetes distribution:"
echo ""
echo "1) K3s (Recommended)"
echo "   - Lightweight Kubernetes"
echo "   - Fast startup, minimal resources"
echo "   - Great for edge/IoT deployments"
echo ""
echo "2) MicroShift"
echo "   - OpenShift-based edge Kubernetes"
echo "   - Enterprise features"
echo "   - Red Hat ecosystem integration"
echo ""

while true; do
    echo -n "Enter your choice (1-2): "
    read DISTRO_CHOICE
    case $DISTRO_CHOICE in
        1)
            BOOTC_IMAGE_DEFAULT="ghcr.io/ramaedge/os-builder:latest"
            HOSTNAME_DEFAULT="fedora-k3s"
            DISTRO_NAME="K3s"
            KUBECONFIG_PATH="/etc/rancher/k3s/k3s.yaml"
            SERVICE_NAME="k3s"
            echo "✅ Selected: K3s (Lightweight Kubernetes)"
            break
            ;;
        2)
            BOOTC_IMAGE_DEFAULT="ghcr.io/ramaedge/os-builder:microshift-latest"
            HOSTNAME_DEFAULT="fedora-microshift"
            DISTRO_NAME="MicroShift"
            KUBECONFIG_PATH="/var/lib/microshift/resources/kubeadmin/kubeconfig"
            SERVICE_NAME="microshift"
            echo "✅ Selected: MicroShift (OpenShift-based)"
            break
            ;;
        *)
            echo "❌ Invalid choice. Please enter 1 or 2."
            ;;
    esac
done

echo ""

# User account configuration
echo "👤 User Account Setup"
echo "---------------------"
echo ""

while true; do
    echo -n "Enter username: "
    read USERNAME
    if [[ "$USERNAME" =~ ^[a-z_][a-z0-9_-]*$ ]] && [[ ${#USERNAME} -le 32 ]]; then
        break
    else
        echo "❌ Invalid username. Use lowercase letters, numbers, underscore, and hyphen only (max 32 chars)"
    fi
done

while true; do
    echo -n "Enter password: "
    read -s PASSWORD
    echo ""
    echo -n "Confirm password: "
    read -s PASSWORD_CONFIRM
    echo ""
    if [[ "$PASSWORD" == "$PASSWORD_CONFIRM" ]] && [[ ${#PASSWORD} -ge 8 ]]; then
        break
    else
        echo "❌ Passwords don't match or too short (minimum 8 characters)"
    fi
done

echo ""
echo "✅ User account configured: $USERNAME"
echo ""

# Create user configuration for kickstart
cat > /tmp/user-include << EOF
user --name=$USERNAME --groups=wheel --plaintext --password=$PASSWORD
EOF

# Create network configuration with selected hostname
cat > /tmp/network-include << EOF
network --bootproto=dhcp --device=link --activate --onboot=on --hostname=$HOSTNAME_DEFAULT
EOF

# Store distribution choice for post-install
cat > /tmp/distro-config << EOF
BOOTC_IMAGE_DEFAULT="$BOOTC_IMAGE_DEFAULT"
DISTRO_NAME="$DISTRO_NAME"
KUBECONFIG_PATH="$KUBECONFIG_PATH"
SERVICE_NAME="$SERVICE_NAME"
EOF

echo ""
echo "✅ Configuration complete!"
echo "   User: $USERNAME"
echo "   Distribution: $DISTRO_NAME"
echo "   Hostname: $HOSTNAME_DEFAULT"
echo ""

# Display partitioning options to user
clear
echo "==================================="
echo "Fedora bootc Interactive Installer"
echo "==================================="
echo ""
echo "Choose your disk partitioning layout:"
echo ""
echo "1) Simple Layout (Recommended)"
echo "   - Single root partition (XFS)"
echo "   - Automatic sizing"
echo ""
echo "2) Advanced Layout" 
echo "   - Separate /home partition"
echo "   - Separate /var partition"
echo "   - Custom sizing"
echo ""
echo "3) Developer Layout"
echo "   - Separate /home, /var, /opt partitions"
echo "   - Extra space for containers"
echo ""
echo "4) Custom Layout"
echo "   - Manual partitioning"
echo ""

while true; do
    echo -n "Enter your choice (1-4): "
    read choice
    case $choice in
        1)
            echo "Creating simple layout..."
            cat > /tmp/part-include << 'EOF'
clearpart --all --initlabel --disklabel=gpt
reqpart --add-boot
part / --grow --fstype=xfs --label=root --size=8192
EOF
            break
            ;;
        2)
            echo "Creating advanced layout..."
            cat > /tmp/part-include << 'EOF'
clearpart --all --initlabel --disklabel=gpt
reqpart --add-boot
part / --fstype=xfs --label=root --size=10240
part /home --fstype=xfs --label=home --size=10240
part /var --fstype=xfs --label=var --size=8192 --grow
EOF
            break
            ;;
        3)
            echo "Creating developer layout..."
            cat > /tmp/part-include << 'EOF'
clearpart --all --initlabel --disklabel=gpt
reqpart --add-boot
part / --fstype=xfs --label=root --size=12288
part /home --fstype=xfs --label=home --size=20480
part /var --fstype=xfs --label=var --size=10240
part /opt --fstype=xfs --label=opt --size=8192 --grow
EOF
            break
            ;;
        4)
            echo "Manual partitioning will be available during installation."
            cat > /tmp/part-include << 'EOF'
clearpart --all --initlabel --disklabel=gpt
reqpart --add-boot
# Manual partitioning - installer will prompt
EOF
            break
            ;;
        *)
            echo "Invalid choice. Please enter 1, 2, 3, or 4."
            ;;
    esac
done

echo ""
echo "Partitioning layout configured."
echo "Installation will continue..."
echo ""

%end

# Post-installation script for additional configuration
%post --interpreter=/bin/bash
#!/bin/bash

echo "Starting bootc container image installation..."

# Load distribution configuration from pre-install
source /tmp/distro-config

# Install our custom bootc container image
# This switches from the base Fedora bootc to our customized edge OS image
echo "Switching to custom bootc container image..."

# Use selected image, but allow override via kernel parameter
BOOTC_IMAGE="$BOOTC_IMAGE_DEFAULT"

# Check for custom image in kernel command line
if grep -q "bootc.image=" /proc/cmdline; then
    BOOTC_IMAGE=$(grep -o 'bootc\.image=[^ ]*' /proc/cmdline | cut -d= -f2)
    echo "Using custom bootc image from kernel parameter: $BOOTC_IMAGE"
fi

# Install bootc if not already available
if ! command -v bootc &> /dev/null; then
    echo "Installing bootc..."
    dnf install -y bootc
fi

# Switch to our custom container image
echo "Switching to bootc image: $BOOTC_IMAGE"
if bootc switch --transport registry "$BOOTC_IMAGE"; then
    echo "Successfully switched to custom bootc image: $BOOTC_IMAGE"
else
    echo "Warning: Failed to switch to custom bootc image, using base image"
    echo "The system will use the default Fedora bootc image"
fi

# Security hardening - deployment-specific configuration
echo "Applying security hardening..."

# File permission hardening
find /usr /etc -xdev -type f -perm -0002 -exec chmod o-w {} \; 2>/dev/null || true
find /usr /etc -xdev -type d -perm -0002 -exec chmod o-w {} \; 2>/dev/null || true

# Secure sensitive files
chmod 600 /etc/ssh/ssh_host_*_key 2>/dev/null || true
chmod 644 /etc/ssh/ssh_host_*_key.pub 2>/dev/null || true
chmod 600 /etc/ssh/sshd_config 2>/dev/null || true
chmod 644 /etc/passwd /etc/group
chmod 640 /etc/shadow /etc/gshadow

# Remove unnecessary system accounts (if they exist)
for user in games ftp; do
    if id "$user" &>/dev/null; then
        userdel -r "$user" 2>/dev/null || true
    fi
done

# Remove unnecessary groups
for group in games; do
    if getent group "$group" &>/dev/null; then
        groupdel "$group" 2>/dev/null || true
    fi
done

# Secure kernel parameters
cat >> /etc/sysctl.d/99-security.conf << 'EOF'
# Network security
net.ipv4.ip_forward = 1
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.tcp_syncookies = 1

# Memory protection
kernel.dmesg_restrict = 1
kernel.kptr_restrict = 1
kernel.yama.ptrace_scope = 1
EOF

# Configure SSH security
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/#MaxAuthTries 6/MaxAuthTries 3/' /etc/ssh/sshd_config
echo "AllowGroups wheel" >> /etc/ssh/sshd_config

# Create welcome message
cat > /etc/motd << EOF
==========================================
Welcome to Fedora bootc Edge OS
==========================================

This system was installed using an interactive
Kickstart configuration with your custom settings.

User account: Created during installation (member of wheel group)
SSH access: Enabled
Container runtime: Podman (pre-installed)
Kubernetes: $DISTRO_NAME

For more information:
- Check system status: bootc status
- View container images: podman images
- Service status: systemctl status $SERVICE_NAME

To get started:
- sudo systemctl enable --now $SERVICE_NAME
- export KUBECONFIG=$KUBECONFIG_PATH

==========================================
EOF

# Enable and configure essential services
systemctl enable sshd
systemctl enable chronyd

# Configure container storage
mkdir -p /etc/containers
cat > /etc/containers/storage.conf << 'EOF'
[storage]
driver = "overlay"
runroot = "/run/containers/storage"
graphroot = "/var/lib/containers/storage"

[storage.options]
additionalimagestores = [
]

[storage.options.overlay]
mountopt = "nodev,metacopy=on"
EOF

# Set up sudoers for wheel group
echo "%wheel ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/wheel-nopasswd

# Configure NetworkManager for better container networking
cat > /etc/NetworkManager/conf.d/cni.conf << 'EOF'
[main]
dns=none

[logging]
level=INFO
EOF

# Create startup script for first boot configuration
cat > /usr/local/bin/first-boot-setup.sh << 'EOF'
#!/bin/bash
# First boot setup script

echo "==================================="
echo "Fedora bootc First Boot Setup"
echo "==================================="
echo ""

# Check if this is the first boot
if [ ! -f /var/lib/first-boot-done ]; then
    echo "Performing first boot setup..."
    
    # Update bootc
    bootc upgrade --check || true
    
    # Pull essential container images
    echo "Pulling essential container images..."
    systemctl --user enable --now podman.socket || true
    
    # Mark first boot as done
    touch /var/lib/first-boot-done
    
    echo "First boot setup completed!"
else
    echo "System already configured."
fi

echo ""
echo "System ready for use!"
echo "==================================="
EOF

chmod +x /usr/local/bin/first-boot-setup.sh

# Create systemd service for first boot
cat > /etc/systemd/system/first-boot-setup.service << 'EOF'
[Unit]
Description=First Boot Setup
After=network-online.target
Wants=network-online.target
ConditionPathExists=!/var/lib/first-boot-done

[Service]
Type=oneshot
ExecStart=/usr/local/bin/first-boot-setup.sh
RemainAfterExit=yes
StandardOutput=journal+console

[Install]
WantedBy=multi-user.target
EOF

systemctl enable first-boot-setup.service

echo "Post-installation configuration completed."

%end

# Package selection is handled by the bootc container image
# No %packages section needed as we're installing a container image

# Reboot after installation
reboot --eject 