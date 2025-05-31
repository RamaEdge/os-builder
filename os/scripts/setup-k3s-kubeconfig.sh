#!/bin/bash
# Wait for K3s to be ready and copy kubeconfig
set -euo pipefail

# Logging function
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | systemd-cat -t k3s-kubeconfig-setup
}

log "Starting K3s kubeconfig setup..."

# Wait for K3s to generate the kubeconfig
max_attempts=60
attempt=0

while [ $attempt -lt $max_attempts ]; do
    if [ -f /etc/rancher/k3s/k3s.yaml ]; then
        log "K3s kubeconfig found, setting up for users..."
        
        # Create kubeconfig directory for fedora user
        mkdir -p /home/fedora/.kube
        
        # Copy kubeconfig for fedora user
        cp /etc/rancher/k3s/k3s.yaml /home/fedora/.kube/config
        chown fedora:fedora /home/fedora/.kube/config
        chmod 600 /home/fedora/.kube/config
        
        # Also create a symlink for root convenience
        mkdir -p /root/.kube
        ln -sf /etc/rancher/k3s/k3s.yaml /root/.kube/config
        
        log "Kubeconfig setup completed for users fedora and root"
        
        # Test the configuration
        if /usr/bin/kubectl --kubeconfig=/etc/rancher/k3s/k3s.yaml get nodes &>/dev/null; then
            log "K3s cluster is responsive"
        else
            log "Warning: K3s cluster not yet responsive"
        fi
        
        exit 0
    fi
    sleep 5
    ((attempt++))
    log "Waiting for K3s kubeconfig... attempt $attempt/$max_attempts"
done

log "Warning: K3s kubeconfig not available after 5 minutes"
exit 1 