# Self-Hosted Runner Migration - Raspberry Pi + Podman

This document outlines the migration of all GitHub Actions workflows from GitHub-hosted runners to self-hosted Raspberry Pi runners using Podman.

## 🎯 Overview

All workflows in this repository have been updated to run on self-hosted Raspberry Pi runners with Podman instead of GitHub-hosted runners (`ubuntu-latest`). This provides better performance, cost optimization, control over the build environment, and leverages ARM64 architecture.

## 📋 Changes Made

### Workflows Updated

| Workflow File | Jobs Updated | Previous | Current |
|---------------|--------------|----------|---------|
| `build-and-security-scan.yaml` | 5 jobs | `ubuntu-latest` | `self-hosted` |
| `microshift-builder.yaml` | 3 jobs | `ubuntu-latest` | `self-hosted` |
| `dependency-update.yaml` | 3 jobs | `ubuntu-latest` | `self-hosted` |

### Jobs Converted

#### build-and-security-scan.yaml
- `gitversion` - Determine Version
- `security-scan-files` - Security Scan - Files  
- `build-and-scan` - Build, Scan and Test Container Image
- `build-iso` - Build ISO Image
- `security-summary` - Security Summary

#### microshift-builder.yaml
- `discover-versions` - Discover Available Versions
- `check-and-build` - Check and Build MicroShift
- `notify-main-workflows` - Notify Main Workflows

#### dependency-update.yaml
- `check-base-image` - Check Base Image Updates
- `analyze-packages` - Analyze Package Vulnerabilities
- `security-advisory` - Generate Security Advisory

## 🖥️ Self-Hosted Runner Requirements

### System Requirements

| Component | Minimum | Recommended | Notes |
|-----------|---------|-------------|-------|
| **Hardware** | Raspberry Pi 4 | Raspberry Pi 5 | ARM64 architecture |
| **OS** | Raspberry Pi OS | Raspberry Pi OS 64-bit | Debian-based Linux |
| **CPU** | 4 cores | 4+ cores (Pi 5) | ARM Cortex-A76 |
| **Memory** | 4GB RAM | 8GB+ RAM | MicroShift builds are memory-intensive |
| **Disk** | 32GB SD card | 64GB+ SD card or SSD | Container images and build artifacts |
| **Network** | Ethernet/WiFi | Gigabit Ethernet | For pulling images and dependencies |

### Software Dependencies

```bash
# Raspberry Pi OS (Debian-based)
sudo apt update
sudo apt install -y \
  podman \
  git \
  build-essential \
  curl \
  jq \
  golang-go

# Configure Podman for rootless operation
sudo usermod --add-subuids 100000-165535 --add-subgids 100000-165535 $USER
podman system migrate

# Optional: Enable Podman socket for Docker compatibility
systemctl --user enable --now podman.socket

# Reboot or re-login for user namespace changes to take effect
sudo reboot
```

### Container Runtime Configuration

The workflows use **Podman exclusively**:
- **Podman**: Rootless, daemonless container runtime
- **Docker Compatibility**: Podman provides Docker-compatible CLI
- **Security**: Runs without root privileges for better security
- **ARM64 Native**: Optimized for Raspberry Pi ARM architecture

## 🚀 Benefits

### Performance Improvements
- **ARM64 Native**: Builds run natively on ARM architecture (no emulation)
- **Dedicated resources**: No resource sharing with other workflows
- **Better caching**: Persistent storage between runs on local disk
- **No queue times**: Immediate execution when runners are available

### Cost Optimization
- **Zero GitHub Actions minutes**: Complete elimination of GitHub Actions usage costs
- **Low power consumption**: Raspberry Pi uses minimal electricity
- **Predictable costs**: One-time hardware cost vs. usage-based GitHub Actions

### Enhanced Control & Security
- **Rootless containers**: Podman runs without root privileges
- **Custom environments**: Install specific tools and dependencies
- **Air-gapped option**: Can run without internet for sensitive builds
- **Direct debugging**: SSH access to runner for troubleshooting
- **ARM64 Ecosystem**: Native ARM container builds

## 🛠️ Setup Instructions

### 1. Register Self-Hosted Runner

1. **Navigate to Repository Settings**
   - Go to your repository on GitHub
   - Click Settings → Actions → Runners

2. **Add New Runner**
   - Click "New self-hosted runner"
   - Select your operating system (Linux)
   - Follow the provided setup commands

3. **Download and Configure**
   ```bash
   # Example commands (use the ones provided by GitHub)
   mkdir actions-runner && cd actions-runner
   curl -o actions-runner-linux-x64-2.311.0.tar.gz -L https://github.com/actions/runner/releases/download/v2.311.0/actions-runner-linux-x64-2.311.0.tar.gz
   tar xzf ./actions-runner-linux-x64-2.311.0.tar.gz
   
   # Configure runner
   ./config.sh --url https://github.com/your-org/os-builder --token YOUR_TOKEN
   ```

### 2. Install Dependencies

```bash
# Install container runtimes
sudo apt update
sudo apt install -y docker.io podman

# Install build tools for Raspberry Pi
sudo apt install -y git build-essential curl jq golang-go

# Install GitVersion for ARM64 (optional, for local version detection)
curl -L https://github.com/GitTools/GitVersion/releases/download/5.12.0/gitversion-linux-arm64-5.12.0.tar.gz | sudo tar -xz -C /usr/local/bin
```

### 3. Start Runner

```bash
# Start runner interactively (for testing)
./run.sh

# Or install as service (for production)
sudo ./svc.sh install
sudo ./svc.sh start
```

### 4. Verify Setup

1. **Check Runner Status**
   - In GitHub repository settings, verify runner shows as "Online"
   - Check runner labels and capabilities

2. **Test Workflow**
   - Trigger a workflow manually to verify it runs on self-hosted runner
   - Monitor workflow logs for any issues

## 🔧 Configuration Options

### Runner Labels

You can add custom labels when configuring the runner:

```bash
./config.sh --url https://github.com/your-org/os-builder --token YOUR_TOKEN --labels "high-memory,docker,fast-disk"
```

Then use specific labels in workflows:
```yaml
runs-on: [self-hosted, high-memory]
```

### Multiple Runners

For high availability and parallel execution:

1. **Set up multiple runners** on different machines
2. **Use same labels** so workflows can run on any available runner
3. **Monitor capacity** and add runners as needed

## 📊 Monitoring and Maintenance

### Health Checks

```bash
# Check runner status
sudo systemctl status actions.runner.*

# Check disk space (important for SD cards)
df -h

# Check memory usage
free -h

# Check Podman status
podman --version
podman system info

# Check temperature (Raspberry Pi specific)
vcgencmd measure_temp
```

### Cleanup

```bash
# Clean up Podman images and containers (weekly)
podman system prune -af

# Clean up workflow artifacts
find ~/actions-runner/_work -type f -mtime +7 -delete

# Monitor SD card wear (if using SD card)
sudo dmesg | grep -i "mmc\|sd"

# Clean up temporary files
sudo apt autoremove -y
sudo apt autoclean
```

### Logs

```bash
# Runner service logs
sudo journalctl -u actions.runner.* -f

# Workflow logs are available in GitHub UI
```

## ⚠️ Security Considerations

### Access Control
- **Limit runner access**: Only trusted users should access runner machines
- **Network security**: Isolate runners from sensitive network segments
- **Regular updates**: Keep OS and software dependencies updated

### Secrets Management
- **Environment isolation**: Use separate runners for different security levels
- **Secret access**: Self-hosted runners have access to repository secrets
- **Audit logs**: Monitor runner usage and workflow execution

## 🔗 References

- [GitHub Self-Hosted Runners Documentation](https://docs.github.com/en/actions/hosting-your-own-runners)
- [Container Security Best Practices](https://docs.docker.com/develop/security-best-practices/)
- [Actions Runner Controller](https://github.com/actions-runner-controller/actions-runner-controller) (for Kubernetes deployments)

## 📞 Support

If you encounter issues with self-hosted runners:

1. **Check runner logs**: `sudo journalctl -u actions.runner.*`
2. **Verify connectivity**: Ensure outbound internet access
3. **Review dependencies**: Confirm all required software is installed
4. **GitHub Status**: Check GitHub Actions service status
5. **Community**: GitHub Actions community forums and documentation 