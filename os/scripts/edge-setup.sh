#!/bin/bash
# Edge deployment first-boot setup (variant-agnostic)
set -euo pipefail

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | systemd-cat -t edge-setup
}

log "Starting edge setup..."

# Hostname
if [ "$(hostname)" = "localhost.localdomain" ] || [ "$(hostname)" = "fedora" ]; then
    hostnamectl set-hostname "edge-$(cat /proc/sys/kernel/random/uuid | cut -d'-' -f1)"
    log "Set hostname to: $(hostname)"
fi

# SSH hardening
mkdir -p /home/fedora/.ssh && chown fedora:fedora /home/fedora/.ssh && chmod 700 /home/fedora/.ssh
if [ ! -f /etc/ssh/sshd_config.d/99-edge-security.conf ]; then
    cat > /etc/ssh/sshd_config.d/99-edge-security.conf << 'EOF'
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
ChallengeResponseAuthentication no
UsePAM yes
X11Forwarding no
ClientAliveInterval 300
ClientAliveCountMax 2
MaxAuthTries 3
EOF
    log "SSH hardened"
fi

# Journald limits for edge
mkdir -p /etc/systemd/journald.conf.d
cat > /etc/systemd/journald.conf.d/edge.conf << 'EOF'
[Journal]
SystemMaxUse=100M
RuntimeMaxUse=50M
MaxRetentionSec=1week
EOF
systemctl restart systemd-journald

# Log rotation
cat > /etc/logrotate.d/edge-logs << 'EOF'
/var/log/*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
}
EOF

# Container auto-update and NTP
systemctl enable --now podman-auto-update.timer
timedatectl set-ntp true

log "Edge setup completed"
