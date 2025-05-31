# 📚 Examples Directory

This directory contains example configurations and scripts for working with your Fedora Edge OS deployment. These examples work with both **K3s** and **MicroShift** distributions.

## 📁 Files Overview

### 1. `cloud-init.yaml` - Post-Installation Configuration
A comprehensive cloud-init configuration that automatically sets up your system after deployment.

**Features:**
- **Distribution-agnostic**: Works with both K3s and MicroShift
- **Dynamic kubeconfig setup**: Automatically detects and configures kubectl access
- **User management**: Configurable username and SSH key setup
- **Helpful aliases**: Pre-configured shell shortcuts for common tasks
- **Observability ready**: Includes commands for monitoring and debugging

### 2. `test-observability.sh` - Observability Stack Tester
A comprehensive test script that validates your OpenTelemetry observability stack.

**Features:**
- **Auto-detection**: Automatically identifies K3s or MicroShift
- **Comprehensive testing**: Tests services, endpoints, and Kubernetes resources
- **Colored output**: Easy-to-read status indicators
- **Troubleshooting guidance**: Provides next steps for issues

## 🚀 Usage Instructions

### Using cloud-init.yaml

#### Step 1: Customize the File
Before using, you **must** customize the configuration:

```bash
# Copy the example
cp os/examples/cloud-init.yaml my-cloud-init.yaml

# Edit the file
vim my-cloud-init.yaml
```

**Required customizations:**
1. **Username**: Change `edgeuser` to your actual username (must match kickstart)
2. **SSH Keys**: Replace the example SSH keys with your actual public keys
3. **Hostname**: Update `fedora-edge-001` to your desired hostname

#### Step 2: Deploy with the ISO
When booting your ISO, you can provide the cloud-init file:

```bash
# Option 1: Via HTTP server
# Host the file on a web server and boot with:
# cloud-init-url=http://your-server/my-cloud-init.yaml

# Option 2: Via local file (if accessible during boot)
# Copy to installation media or network share
```

#### Step 3: Verify Setup
After boot, SSH into your system:

```bash
ssh your-username@<machine-ip>

# Test the setup
distro                    # Shows K3s or MicroShift  
kstatus                   # Shows cluster status
observability             # Shows observability pods
```

### Using test-observability.sh

#### Run the Test Script

```bash
# Make executable
chmod +x os/examples/test-observability.sh

# Run the test
./os/examples/test-observability.sh
```

#### Expected Output

```
🔍 Testing OpenTelemetry Observability Stack
=============================================
📦 Detected distribution: K3s

🖥️  Host-level Services
----------------------
Checking OpenTelemetry Collector... ✓ Active
Checking k3s... ✓ Active

🌐 Network Endpoints
--------------------
Checking OTLP gRPC endpoint... ✓ Accessible
Checking OTLP HTTP endpoint... ✓ Accessible
Checking Host Prometheus metrics... ✓ Accessible
Checking OTel internal metrics... ✓ Accessible

☸️  Kubernetes Resources
-----------------------
k3s cluster: ✓ Active
Checking OTel Collector deployment... ✓ Ready
Checking Jaeger deployment... ✓ Ready

🔗 Cluster Endpoints  
--------------------
Checking Cluster OTLP gRPC (NodePort)... ✓ Accessible
Checking Cluster OTel metrics... ✓ Accessible
Checking Jaeger UI... ✓ Accessible

📊 Quick Metrics Test
---------------------
Fetching sample metrics...
Host CPU metrics: ✓ Available
Cluster metrics: ✓ Available

🎯 Summary
----------
Test completed for k3s distribution!
```

## 🛠️ Customization Guide

### Adding Custom Applications

Edit `cloud-init.yaml` to add your applications:

```yaml
write_files:
  - path: /etc/my-app/config.yaml
    content: |
      # Your app configuration
    permissions: '0644'
    owner: root:root

runcmd:
  - systemctl enable --now my-app
```

### Custom Aliases and Scripts

Add to the `.bashrc_extra` section:

```yaml
alias mycommand='kubectl get pods -n my-namespace'
alias deploy='kubectl apply -f /path/to/manifests/'
```

### Environment-Specific Configuration

Create different cloud-init files for different environments:

```bash
# Development environment
cp cloud-init.yaml cloud-init-dev.yaml
# Edit for dev-specific settings

# Production environment  
cp cloud-init.yaml cloud-init-prod.yaml
# Edit for prod-specific settings
```

## 🔧 Troubleshooting

### Common Issues

1. **Username mismatch**: Ensure cloud-init username matches kickstart username
2. **SSH key issues**: Verify public key format and accessibility
3. **Service failures**: Check with `systemctl status <service>`
4. **Network issues**: Verify connectivity and firewall rules

### Debug Commands

```bash
# Check cloud-init logs
sudo journalctl -u cloud-init

# Check cloud-init status
sudo cloud-init status

# Re-run cloud-init (if needed)
sudo cloud-init clean
sudo cloud-init init
```

### Test Script Issues

```bash
# Run with debug output
bash -x test-observability.sh

# Check individual services
systemctl status otelcol
systemctl status k3s         # or microshift
kubectl get pods --all-namespaces
```

## 📝 Templates

### Quick Template: Minimal cloud-init

```yaml
#cloud-config
hostname: my-edge-device
users:
  - name: myuser
    groups: wheel
    sudo: ALL=(ALL) NOPASSWD:ALL
    ssh_authorized_keys:
      - ssh-rsa YOUR_KEY_HERE
runcmd:
  - /usr/local/bin/setup-kubeconfig
final_message: "Edge OS ready! SSH: ssh myuser@<ip>"
```

### Quick Template: Test Script

```bash
#!/bin/bash
# Quick observability test
./test-observability.sh
kubectl get nodes
kubectl get pods -A
```

## 🔗 Integration with Deployment

These examples integrate seamlessly with your deployment process:

1. **Build ISO**: `make build-iso` (creates unified interactive ISO)
2. **Customize cloud-init**: Edit `cloud-init.yaml` for your environment
3. **Deploy**: Boot ISO, choose distribution, provide cloud-init URL
4. **Validate**: Run `test-observability.sh` to verify deployment
5. **Monitor**: Use built-in aliases and scripts for ongoing management

## 📖 Related Documentation

- [ISO Building Guide](../../docs/ISO_BUILDING.md)
- [Main README](../../README.md)
- [OS README](../README.md) 