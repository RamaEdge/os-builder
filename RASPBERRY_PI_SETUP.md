# Raspberry Pi Self-Hosted Runner Setup Guide

Complete guide to set up a Raspberry Pi as a GitHub Actions self-hosted runner optimized for this repository.

## 🍓 Hardware Requirements

### Recommended Hardware
- **Raspberry Pi 5** (8GB RAM) - Latest generation with best performance
- **64GB+ microSD card** (Class 10, A2 rated) or USB SSD
- **Official Raspberry Pi Power Supply** (USB-C, 5V/5A for Pi 5)
- **Ethernet cable** or **WiFi** connection
- **Heatsink/Fan** (optional but recommended for continuous builds)

### Minimum Hardware
- **Raspberry Pi 4** (4GB RAM minimum, 8GB recommended)
- **32GB microSD card** (Class 10)
- **Official power supply**
- **Network connection**

## 🔧 Initial Raspberry Pi Setup

### 1. Install Raspberry Pi OS

```bash
# Use Raspberry Pi Imager to flash Raspberry Pi OS 64-bit
# Download from: https://rpi.org/imager

# Enable SSH, set username/password, configure WiFi in imager
# Username: runner (recommended)
# Enable SSH with password authentication
```

### 2. Initial System Configuration

```bash
# SSH into your Raspberry Pi
ssh runner@your-pi-ip

# Update system
sudo apt update && sudo apt upgrade -y

# Install essential packages
sudo apt install -y \
  git \
  curl \
  wget \
  build-essential \
  cmake \
  golang-go \
  jq \
  htop \
  tree \
  vim

# Configure timezone
sudo timedatectl set-timezone Your/Timezone

# Optional: Increase GPU memory split for better performance
echo "gpu_mem=16" | sudo tee -a /boot/firmware/config.txt
```

### 3. Install and Configure Podman

```bash
# Install Podman
sudo apt install -y podman

# Configure rootless Podman
sudo usermod --add-subuids 100000-165535 --add-subgids 100000-165535 $USER

# Restart for user namespace changes
sudo reboot
```

After reboot:

```bash
# Initialize rootless Podman
podman system migrate

# Test Podman installation
podman --version
podman run hello-world

# Configure Podman registries
mkdir -p ~/.config/containers
cat > ~/.config/containers/registries.conf << 'EOF'
[registries.search]
registries = ['docker.io', 'quay.io', 'ghcr.io']

[registries.insecure]
registries = []

[registries.block]
registries = []
EOF

# Configure Podman storage (use overlay driver)
cat > ~/.config/containers/storage.conf << 'EOF'
[storage]
driver = "overlay"
runroot = "/run/user/1000/containers"
graphroot = "/home/runner/.local/share/containers/storage"

[storage.options]
mount_program = "/usr/bin/fuse-overlayfs"
EOF
```

### 4. Performance Optimization

```bash
# Increase container limits
echo "fs.inotify.max_user_watches=524288" | sudo tee -a /etc/sysctl.conf
echo "fs.inotify.max_user_instances=512" | sudo tee -a /etc/sysctl.conf

# Configure memory management
echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf

# Apply changes
sudo sysctl -p

# Configure swap (if using SD card, be conservative)
sudo dphys-swapfile swapoff
sudo sed -i 's/CONF_SWAPSIZE=100/CONF_SWAPSIZE=1024/' /etc/dphys-swapfile
sudo dphys-swapfile setup
sudo dphys-swapfile swapon
```

## 🏃‍♂️ GitHub Actions Runner Setup

### 1. Create Runner Directory

```bash
# Create directory for the runner
mkdir -p ~/actions-runner
cd ~/actions-runner
```

### 2. Download GitHub Actions Runner (ARM64)

```bash
# Get latest ARM64 runner release
RUNNER_VERSION=$(curl -s https://api.github.com/repos/actions/runner/releases/latest | jq -r '.tag_name' | sed 's/v//')
curl -o actions-runner-linux-arm64-${RUNNER_VERSION}.tar.gz -L https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-arm64-${RUNNER_VERSION}.tar.gz

# Verify hash (optional)
echo "$(curl -s https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-arm64-${RUNNER_VERSION}.tar.gz.sha256) actions-runner-linux-arm64-${RUNNER_VERSION}.tar.gz" | shasum -a 256 -c

# Extract
tar xzf actions-runner-linux-arm64-${RUNNER_VERSION}.tar.gz
```

### 3. Configure the Runner

```bash
# Configure runner (replace with your repository details)
./config.sh --url https://github.com/YOUR_ORG/os-builder --token YOUR_TOKEN --name "rpi-runner" --labels "self-hosted,linux,arm64,raspberry-pi"

# Install as service
sudo ./svc.sh install runner
sudo ./svc.sh start
```

### 4. Verify Runner Installation

```bash
# Check service status
sudo systemctl status actions.runner.runner.service

# Check runner logs
sudo journalctl -u actions.runner.runner.service -f

# Test Podman functionality
podman pull hello-world
podman run --rm hello-world
```

## 🔧 Repository-Specific Configuration

### 1. Pre-pull Common Images

```bash
# Pre-pull images used by workflows to improve performance
podman pull quay.io/fedora/fedora-bootc:42
podman pull golang:1.23
podman pull quay.io/centos-bootc/bootc-image-builder:latest
podman pull aquasecurity/trivy:latest
```

### 2. Create Workflow Cache Directory

```bash
# Create cache directory for better performance
mkdir -p ~/.cache/podman
mkdir -p ~/.cache/workflows
```

### 3. Configure Git (if needed)

```bash
# Configure Git for the runner user
git config --global user.name "GitHub Actions Runner"
git config --global user.email "runner@example.com"
git config --global init.defaultBranch main
```

## 📊 Monitoring and Maintenance

### 1. System Monitoring

```bash
# Create monitoring script
cat > ~/monitor.sh << 'EOF'
#!/bin/bash
echo "=== Raspberry Pi System Status ==="
echo "Date: $(date)"
echo "Temperature: $(vcgencmd measure_temp)"
echo "CPU Usage: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)%"
echo "Memory Usage: $(free -h | awk 'NR==2{printf "%.1f%%", $3*100/$2}')"
echo "Disk Usage: $(df -h / | awk 'NR==2{print $5}')"
echo "Runner Status: $(sudo systemctl is-active actions.runner.runner.service)"
echo "Podman Images: $(podman images --format 'table {{.Repository}}\t{{.Tag}}\t{{.Size}}')"
echo "==============================="
EOF

chmod +x ~/monitor.sh

# Add to crontab for regular monitoring
(crontab -l 2>/dev/null; echo "0 */6 * * * /home/runner/monitor.sh >> /home/runner/monitor.log") | crontab -
```

### 2. Automated Cleanup

```bash
# Create cleanup script
cat > ~/cleanup.sh << 'EOF'
#!/bin/bash
echo "$(date): Starting cleanup..."

# Clean up Podman
podman system prune -af

# Clean up old workflow artifacts
find ~/actions-runner/_work -type f -mtime +7 -delete 2>/dev/null || true

# Clean up system packages
sudo apt autoremove -y
sudo apt autoclean

# Clear temporary files
sudo rm -rf /tmp/* 2>/dev/null || true

echo "$(date): Cleanup completed"
EOF

chmod +x ~/cleanup.sh

# Add to crontab for weekly cleanup
(crontab -l 2>/dev/null; echo "0 2 * * 0 /home/runner/cleanup.sh >> /home/runner/cleanup.log") | crontab -
```

### 3. Temperature Monitoring

```bash
# Create temperature alert script
cat > ~/temp_check.sh << 'EOF'
#!/bin/bash
TEMP=$(vcgencmd measure_temp | cut -d= -f2 | cut -d\' -f1)
THRESHOLD=75

if (( $(echo "$TEMP > $THRESHOLD" | bc -l) )); then
    echo "$(date): WARNING - Temperature is ${TEMP}°C (threshold: ${THRESHOLD}°C)" >> ~/temp_warnings.log
    # Optional: Send notification or slow down runner
fi
EOF

chmod +x ~/temp_check.sh

# Check temperature every 5 minutes
(crontab -l 2>/dev/null; echo "*/5 * * * * /home/runner/temp_check.sh") | crontab -
```

## 🚨 Troubleshooting

### Common Issues

1. **Runner not appearing online**
   ```bash
   # Check service status
   sudo systemctl status actions.runner.runner.service
   
   # Restart service
   sudo systemctl restart actions.runner.runner.service
   ```

2. **Podman permission issues**
   ```bash
   # Verify rootless configuration
   podman system info | grep -A5 "runRoot\|graphRoot"
   
   # Reset Podman storage
   podman system reset --force
   ```

3. **Memory issues during builds**
   ```bash
   # Monitor memory usage
   watch -n 1 'free -h && echo "---" && podman stats --no-stream'
   
   # Increase swap if needed
   sudo dphys-swapfile swapoff
   sudo sed -i 's/CONF_SWAPSIZE=.*/CONF_SWAPSIZE=2048/' /etc/dphys-swapfile
   sudo dphys-swapfile setup
   sudo dphys-swapfile swapon
   ```

4. **SD card performance issues**
   ```bash
   # Check for SD card errors
   sudo dmesg | grep -i "mmc\|sd"
   
   # Consider switching to USB SSD for better performance
   ```

### Performance Tuning

1. **Enable GPU memory split**
   ```bash
   echo "gpu_mem=16" | sudo tee -a /boot/firmware/config.txt
   sudo reboot
   ```

2. **Optimize CPU governor**
   ```bash
   echo 'GOVERNOR="performance"' | sudo tee /etc/default/cpufrequtils
   sudo systemctl restart cpufrequtils
   ```

3. **Disable unnecessary services**
   ```bash
   sudo systemctl disable bluetooth
   sudo systemctl disable cups
   sudo systemctl disable avahi-daemon
   ```

## 🔗 References

- [Raspberry Pi Documentation](https://www.raspberrypi.org/documentation/)
- [Podman Documentation](https://docs.podman.io/)
- [GitHub Actions Self-Hosted Runners](https://docs.github.com/en/actions/hosting-your-own-runners)
- [ARM64 Container Best Practices](https://www.docker.com/blog/getting-started-with-docker-for-arm-on-linux/)

## 📞 Support

For issues specific to this setup:

1. Check the monitoring logs: `~/monitor.log`
2. Review runner logs: `sudo journalctl -u actions.runner.runner.service`
3. Monitor temperature: `~/temp_warnings.log`
4. Check Podman status: `podman system info` 