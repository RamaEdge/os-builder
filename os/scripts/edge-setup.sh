#!/bin/bash
# Edge deployment setup script
# This script runs at boot time to configure edge-specific settings

set -euo pipefail

# Logging function
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | systemd-cat -t edge-setup
}

log "Starting edge setup configuration..."

# Configure hostname if not already set
if [ "$(hostname)" = "localhost.localdomain" ] || [ "$(hostname)" = "fedora" ]; then
    NEW_HOSTNAME="edge-$(cat /proc/sys/kernel/random/uuid | cut -d'-' -f1)"
    hostnamectl set-hostname "$NEW_HOSTNAME"
    log "Set hostname to: $NEW_HOSTNAME"
fi

# Ensure SSH keys directory exists
mkdir -p /home/fedora/.ssh
chown fedora:fedora /home/fedora/.ssh
chmod 700 /home/fedora/.ssh

# Configure SSH for better security
if [ ! -f /etc/ssh/sshd_config.d/99-edge-security.conf ]; then
    cat > /etc/ssh/sshd_config.d/99-edge-security.conf << 'EOF'
# Edge deployment SSH security configuration
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
ChallengeResponseAuthentication no
UsePAM yes
X11Forwarding no
PrintMotd no
ClientAliveInterval 300
ClientAliveCountMax 2
MaxAuthTries 3
EOF
    log "Configured SSH security settings"
fi

# Configure firewall for edge deployment
firewall-cmd --permanent --zone=public --add-service=ssh
firewall-cmd --permanent --zone=public --add-service=cockpit
# MicroShift firewall rules
firewall-cmd --permanent --zone=public --add-port=6443/tcp  # Kubernetes API
firewall-cmd --permanent --zone=public --add-port=8080/tcp  # Health checks
firewall-cmd --permanent --zone=public --add-port=10250/tcp # Kubelet API
firewall-cmd --permanent --zone=public --add-port=10251/tcp # Kube-scheduler
firewall-cmd --permanent --zone=public --add-port=80/tcp    # HTTP ingress
firewall-cmd --permanent --zone=public --add-port=443/tcp   # HTTPS ingress
# OpenTelemetry firewall rules
firewall-cmd --permanent --zone=public --add-port=4317/tcp  # OTLP gRPC
firewall-cmd --permanent --zone=public --add-port=4318/tcp  # OTLP HTTP
firewall-cmd --permanent --zone=public --add-port=9090/tcp  # Prometheus metrics
firewall-cmd --permanent --zone=public --add-port=8888/tcp  # OTel internal metrics
firewall-cmd --reload
log "Configured firewall rules including MicroShift and OpenTelemetry ports"

# Set up log rotation for edge devices (smaller logs)
cat > /etc/logrotate.d/edge-logs << 'EOF'
/var/log/*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    sharedscripts
}
EOF

# Configure journald for edge devices
cat > /etc/systemd/journald.conf.d/edge.conf << 'EOF'
[Journal]
SystemMaxUse=100M
RuntimeMaxUse=50M
MaxRetentionSec=1week
EOF
systemctl restart systemd-journald
log "Configured logging for edge deployment"

# Set up container auto-update
systemctl enable --now podman-auto-update.timer
log "Enabled container auto-update"

# Configure time synchronization
timedatectl set-ntp true
log "Enabled NTP synchronization"

# Configure MicroShift
if systemctl is-enabled microshift &>/dev/null; then
    log "Configuring MicroShift for edge deployment"
    
    # Ensure cri-o is started before microshift
    systemctl enable --now crio
    
    # Create kubeconfig directory for fedora user
    mkdir -p /home/fedora/.kube
    
    # Set proper ownership (MicroShift will create the actual kubeconfig after it starts)
    chown fedora:fedora /home/fedora/.kube
    
    # Create a script to copy kubeconfig when MicroShift is ready
    cat > /usr/local/bin/setup-kubeconfig.sh << 'EOF'
#!/bin/bash
# Wait for MicroShift to be ready and copy kubeconfig
set -euo pipefail

# Wait for MicroShift to generate the kubeconfig
max_attempts=60
attempt=0

while [ $attempt -lt $max_attempts ]; do
    if [ -f /var/lib/microshift/resources/kubeadmin/kubeconfig ]; then
        # Copy kubeconfig for fedora user
        cp /var/lib/microshift/resources/kubeadmin/kubeconfig /home/fedora/.kube/config
        chown fedora:fedora /home/fedora/.kube/config
        chmod 600 /home/fedora/.kube/config
        echo "Kubeconfig setup complete for user fedora"
        exit 0
    fi
    sleep 5
    ((attempt++))
done

echo "Warning: MicroShift kubeconfig not available after 5 minutes"
exit 1
EOF
    chmod +x /usr/local/bin/setup-kubeconfig.sh
    
    log "MicroShift configuration completed"
    
    # Deploy observability stack automatically
    cat > /usr/local/bin/deploy-observability.sh << 'EOF'
#!/bin/bash
# Deploy observability stack to MicroShift
set -euo pipefail

# Wait for MicroShift to be ready
max_attempts=60
attempt=0

while [ $attempt -lt $max_attempts ]; do
    if kubectl get nodes &>/dev/null; then
        echo "MicroShift is ready, deploying observability stack..."
        
        # Deploy the observability manifests
        kubectl apply -f /etc/microshift/manifests/observability-stack.yaml
        
        # Wait for deployments to be ready
        kubectl wait --for=condition=available --timeout=300s deployment/otel-collector -n observability
        kubectl wait --for=condition=available --timeout=300s deployment/jaeger -n observability
        
        echo "Observability stack deployed successfully!"
        echo "Access points:"
        echo "- Jaeger UI: http://localhost:30686"
        echo "- OpenTelemetry Metrics: http://localhost:30464/metrics"
        echo "- Host Prometheus: http://localhost:9090/metrics"
        
        exit 0
    fi
    sleep 5
    ((attempt++))
done

echo "Warning: MicroShift not ready after 5 minutes, observability deployment skipped"
exit 1
EOF
    chmod +x /usr/local/bin/deploy-observability.sh
    
fi

# Configure OpenTelemetry Collector on host
if systemctl is-enabled otel-collector &>/dev/null; then
    log "Configuring OpenTelemetry Collector"
    
    # Ensure the collector starts after network
    systemctl enable --now otel-collector
    
    log "OpenTelemetry Collector configuration completed"
fi

log "Edge setup configuration completed successfully" 