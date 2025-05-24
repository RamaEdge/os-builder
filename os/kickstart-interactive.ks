# Advanced Interactive Kickstart Configuration for Fedora bootc
# This kickstart file provides comprehensive interactive installation

# Use text mode installation with full interaction
text

# Language and keyboard (can be changed during installation)
lang en_US.UTF-8
keyboard us

# Interactive network configuration
# Network setup will be handled in %pre script
%include /tmp/network-include

# Time zone (will be prompted during installation)
timezone --utc America/New_York

# Interactive user creation (handled in %pre script)
%include /tmp/user-include

# Root password
rootpw --lock

# Security settings
authselect select sssd with-mkhomedir
selinux --enforcing

# Services
services --enabled=sshd,chronyd,NetworkManager
services --disabled=kdump

# Firewall configuration
firewall --enabled --ssh

# Interactive partitioning
%include /tmp/part-include

# Pre-installation script for comprehensive interactive setup
%pre --interpreter=/bin/bash
#!/bin/bash

# Clear screen and show header
clear
cat << 'EOF'
=========================================================
     Fedora bootc Interactive Installation Wizard
=========================================================

Welcome! This installer will guide you through setting up
your Fedora bootc edge system with your custom configuration.

Press Enter to continue...
EOF
read

# Function to validate IP address
validate_ip() {
    local ip=$1
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        IFS='.' read -ra ADDR <<< "$ip"
        for i in "${ADDR[@]}"; do
            if [[ $i -gt 255 ]]; then
                return 1
            fi
        done
        return 0
    else
        return 1
    fi
}

# Function to validate username
validate_username() {
    local username=$1
    if [[ $username =~ ^[a-z][a-z0-9_-]*$ ]] && [[ ${#username} -ge 3 ]] && [[ ${#username} -le 32 ]]; then
        return 0
    else
        return 1
    fi
}

#===========================================
# USER CONFIGURATION
#===========================================
clear
echo "========================================="
echo "USER ACCOUNT CONFIGURATION"
echo "========================================="
echo ""

while true; do
    echo -n "Enter username (3-32 chars, lowercase, start with letter): "
    read USERNAME
    if validate_username "$USERNAME"; then
        break
    else
        echo "Invalid username. Please use 3-32 lowercase characters, starting with a letter."
    fi
done

while true; do
    echo -n "Enter password for $USERNAME: "
    read -s PASSWORD
    echo ""
    echo -n "Confirm password: "
    read -s PASSWORD_CONFIRM
    echo ""
    if [[ "$PASSWORD" == "$PASSWORD_CONFIRM" ]] && [[ ${#PASSWORD} -ge 8 ]]; then
        break
    else
        echo "Passwords don't match or are too short (minimum 8 characters). Please try again."
    fi
done

echo ""
echo "Additional groups for $USERNAME (space-separated, or press Enter for default 'wheel'):"
echo "Available groups: wheel docker podman systemd-journal"
read -p "Groups: " USER_GROUPS
if [[ -z "$USER_GROUPS" ]]; then
    USER_GROUPS="wheel"
fi

echo ""
echo -n "Enter SSH public key for $USERNAME (optional, press Enter to skip): "
read SSH_KEY

# Create user configuration
cat > /tmp/user-include << EOF
user --name=$USERNAME --groups=$USER_GROUPS --plaintext --password=$PASSWORD
EOF

#===========================================
# NETWORK CONFIGURATION
#===========================================
clear
echo "========================================="
echo "NETWORK CONFIGURATION"
echo "========================================="
echo ""

echo "Network Configuration Options:"
echo "1) DHCP (Automatic IP configuration)"
echo "2) Static IP configuration"
echo "3) Manual configuration during installation"
echo ""

while true; do
    echo -n "Select network configuration (1-3): "
    read NET_CHOICE
    case $NET_CHOICE in
        1)
            NETWORK_CONFIG="dhcp"
            echo ""
            echo -n "Enter hostname (or press Enter for 'fedora-bootc'): "
            read HOSTNAME
            if [[ -z "$HOSTNAME" ]]; then
                HOSTNAME="fedora-bootc"
            fi
            
            cat > /tmp/network-include << EOF
network --bootproto=dhcp --device=link --activate --onboot=on --hostname=$HOSTNAME
EOF
            break
            ;;
        2)
            NETWORK_CONFIG="static"
            echo ""
            echo "Static IP Configuration:"
            
            while true; do
                echo -n "Enter IP address (e.g., 192.168.1.100): "
                read STATIC_IP
                if validate_ip "$STATIC_IP"; then
                    break
                else
                    echo "Invalid IP address format."
                fi
            done
            
            while true; do
                echo -n "Enter netmask (e.g., 255.255.255.0): "
                read NETMASK
                if validate_ip "$NETMASK"; then
                    break
                else
                    echo "Invalid netmask format."
                fi
            done
            
            while true; do
                echo -n "Enter gateway (e.g., 192.168.1.1): "
                read GATEWAY
                if validate_ip "$GATEWAY"; then
                    break
                else
                    echo "Invalid gateway format."
                fi
            done
            
            echo -n "Enter primary DNS server (e.g., 8.8.8.8): "
            read DNS1
            echo -n "Enter secondary DNS server (optional, press Enter to skip): "
            read DNS2
            
            echo -n "Enter hostname: "
            read HOSTNAME
            
            # Create static network configuration
            DNS_CONFIG="--nameserver=$DNS1"
            if [[ -n "$DNS2" ]]; then
                DNS_CONFIG="$DNS_CONFIG --nameserver=$DNS2"
            fi
            
            cat > /tmp/network-include << EOF
network --bootproto=static --device=link --ip=$STATIC_IP --netmask=$NETMASK --gateway=$GATEWAY $DNS_CONFIG --activate --onboot=on --hostname=$HOSTNAME
EOF
            break
            ;;
        3)
            NETWORK_CONFIG="manual"
            cat > /tmp/network-include << EOF
# Manual network configuration - will be prompted during installation
network --bootproto=dhcp --device=link --activate
EOF
            break
            ;;
        *)
            echo "Invalid choice. Please enter 1, 2, or 3."
            ;;
    esac
done

#===========================================
# FILESYSTEM CONFIGURATION
#===========================================
clear
echo "========================================="
echo "FILESYSTEM CONFIGURATION"
echo "========================================="
echo ""

echo "Choose your disk partitioning layout:"
echo ""
echo "1) Simple Layout (Recommended for most users)"
echo "   - Single root partition with XFS"
echo "   - Minimum 20GB recommended"
echo ""
echo "2) Standard Layout"
echo "   - Separate /home partition"
echo "   - Root partition with XFS"
echo "   - Minimum 30GB recommended"
echo ""
echo "3) Advanced Layout"
echo "   - Separate /home, /var, /opt partitions"
echo "   - Optimized for container workloads"
echo "   - Minimum 50GB recommended"
echo ""
echo "4) Developer Layout"
echo "   - Multiple partitions for development"
echo "   - Extra space for containers and builds"
echo "   - Minimum 80GB recommended"
echo ""
echo "5) Custom Layout"
echo "   - Manual partitioning during installation"
echo ""

while true; do
    echo -n "Enter your choice (1-5): "
    read PART_CHOICE
    case $PART_CHOICE in
        1)
            echo "Creating simple layout..."
            cat > /tmp/part-include << 'EOF'
# Simple layout with single root partition
clearpart --all --initlabel --disklabel=gpt
reqpart --add-boot
part / --grow --fstype=xfs --label=root --size=20480
EOF
            break
            ;;
        2)
            echo "Creating standard layout..."
            cat > /tmp/part-include << 'EOF'
# Standard layout with separate home
clearpart --all --initlabel --disklabel=gpt
reqpart --add-boot
part / --fstype=xfs --label=root --size=15360
part /home --fstype=xfs --label=home --size=10240 --grow
EOF
            break
            ;;
        3)
            echo "Creating advanced layout..."
            cat > /tmp/part-include << 'EOF'
# Advanced layout for container workloads
clearpart --all --initlabel --disklabel=gpt
reqpart --add-boot
part / --fstype=xfs --label=root --size=15360
part /home --fstype=xfs --label=home --size=10240
part /var --fstype=xfs --label=var --size=15360
part /opt --fstype=xfs --label=opt --size=10240 --grow
EOF
            break
            ;;
        4)
            echo "Creating developer layout..."
            cat > /tmp/part-include << 'EOF'
# Developer layout with extra partitions
clearpart --all --initlabel --disklabel=gpt
reqpart --add-boot
part / --fstype=xfs --label=root --size=20480
part /home --fstype=xfs --label=home --size=20480
part /var --fstype=xfs --label=var --size=20480
part /opt --fstype=xfs --label=opt --size=15360
part /usr/local --fstype=xfs --label=usr-local --size=10240 --grow
EOF
            break
            ;;
        5)
            echo "Manual partitioning will be available during installation."
            cat > /tmp/part-include << 'EOF'
# Manual partitioning - installer will provide interface
clearpart --all --initlabel --disklabel=gpt
reqpart --add-boot
# User will configure partitions manually
EOF
            break
            ;;
        *)
            echo "Invalid choice. Please enter 1, 2, 3, 4, or 5."
            ;;
    esac
done

#===========================================
# CONFIGURATION SUMMARY
#===========================================
clear
echo "========================================="
echo "INSTALLATION CONFIGURATION SUMMARY"
echo "========================================="
echo ""
echo "User Account:"
echo "  Username: $USERNAME"
echo "  Groups: $USER_GROUPS"
if [[ -n "$SSH_KEY" ]]; then
    echo "  SSH Key: ${SSH_KEY:0:30}..."
fi
echo ""
echo "Network Configuration:"
case $NET_CHOICE in
    1)
        echo "  Type: DHCP"
        echo "  Hostname: $HOSTNAME"
        ;;
    2)
        echo "  Type: Static IP"
        echo "  IP Address: $STATIC_IP"
        echo "  Netmask: $NETMASK"
        echo "  Gateway: $GATEWAY"
        echo "  DNS: $DNS1 $DNS2"
        echo "  Hostname: $HOSTNAME"
        ;;
    3)
        echo "  Type: Manual (will be configured during installation)"
        ;;
esac
echo ""
echo "Filesystem Layout:"
case $PART_CHOICE in
    1) echo "  Type: Simple (single root partition)" ;;
    2) echo "  Type: Standard (root + home)" ;;
    3) echo "  Type: Advanced (root + home + var + opt)" ;;
    4) echo "  Type: Developer (multiple partitions)" ;;
    5) echo "  Type: Manual (will be configured during installation)" ;;
esac
echo ""
echo "========================================="
echo ""

while true; do
    echo -n "Proceed with installation? (y/n): "
    read CONFIRM
    case $CONFIRM in
        [Yy]*)
            echo "Starting installation..."
            break
            ;;
        [Nn]*)
            echo "Installation cancelled."
            exit 1
            ;;
        *)
            echo "Please answer yes (y) or no (n)."
            ;;
    esac
done

%end

# Post-installation script
%post --interpreter=/bin/bash
#!/bin/bash

# Add SSH key if provided
if [[ -n "$SSH_KEY" ]]; then
    mkdir -p /home/$USERNAME/.ssh
    echo "$SSH_KEY" > /home/$USERNAME/.ssh/authorized_keys
    chmod 700 /home/$USERNAME/.ssh
    chmod 600 /home/$USERNAME/.ssh/authorized_keys
    chown -R $USERNAME:$USERNAME /home/$USERNAME/.ssh
fi

# Create comprehensive welcome message
cat > /etc/motd << EOF
=========================================================
Welcome to Fedora bootc Edge OS
=========================================================

System Configuration:
- User: $USERNAME (groups: $USER_GROUPS)
- Hostname: $(hostname)
- Installation: Interactive Kickstart
- Container Runtime: Podman
- Kubernetes: MicroShift (available)

Quick Start Commands:
- Check bootc status: bootc status
- List containers: podman ps -a
- Enable MicroShift: sudo systemctl enable --now microshift
- Set KUBECONFIG: export KUBECONFIG=/var/lib/microshift/resources/kubeadmin/kubeconfig

Network Configuration:
$(ip addr show | grep -E "inet [0-9]" | grep -v 127.0.0.1)

For support and documentation:
- GitHub: https://github.com/bootc-dev/bootc
- Fedora bootc: https://docs.fedoraproject.org/en-US/bootc/

=========================================================
EOF

# Configure sudoers for wheel group
echo "%wheel ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/wheel-nopasswd

# Enable essential services
systemctl enable sshd chronyd NetworkManager

# Configure container environment
mkdir -p /etc/containers
cat > /etc/containers/policy.json << 'EOF'
{
    "default": [
        {
            "type": "insecureAcceptAnything"
        }
    ],
    "transports":
        {
            "docker-daemon":
                {
                    "": [{"type":"insecureAcceptAnything"}]
                }
        }
}
EOF

echo "Post-installation configuration completed."

%end

# Reboot after installation
reboot --eject 