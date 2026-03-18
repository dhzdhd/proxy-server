#!/bin/bash
set -euo pipefail
exec > /var/log/user-data.log 2>&1

echo "=== Bootstrap started at $(date -u) ==="

# ── System update ─────────────────────────────────────────────────────────────
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"

# ── Install WireGuard and tools ───────────────────────────────────────────────
apt-get install -y wireguard wireguard-tools ufw fail2ban

# ── Kernel: enable IP forwarding ─────────────────────────────────────────────
cat > /etc/sysctl.d/99-wireguard.conf <<'EOF'
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
# Reverse path filtering — set to loose for WireGuard
net.ipv4.conf.all.rp_filter = 2
EOF
sysctl --system

# ── Detect primary network interface ─────────────────────────────────────────
PRIMARY_IF=$(ip route | awk '/^default/{print $5; exit}')
echo "Primary interface: $PRIMARY_IF"

# ── WireGuard server config ───────────────────────────────────────────────────
mkdir -p /etc/wireguard
chmod 700 /etc/wireguard

cat > /etc/wireguard/wg0.conf <<WGEOF
[Interface]
Address     = ${wg_server_ipv4}, ${wg_server_ipv6}
ListenPort  = ${wireguard_port}
PrivateKey  = ${wg_server_private_key}

# NAT — masquerade all VPN traffic going out through the primary interface
PostUp   = iptables  -t nat -A POSTROUTING -o $PRIMARY_IF -j MASQUERADE
PostUp   = ip6tables -t nat -A POSTROUTING -o $PRIMARY_IF -j MASQUERADE
PostDown = iptables  -t nat -D POSTROUTING -o $PRIMARY_IF -j MASQUERADE
PostDown = ip6tables -t nat -D POSTROUTING -o $PRIMARY_IF -j MASQUERADE

[Peer]
# Your PC
PublicKey  = ${wg_client_public_key}
AllowedIPs = ${wg_client_ipv4}, ${wg_client_ipv6}
WGEOF

chmod 600 /etc/wireguard/wg0.conf

# ── Enable and start WireGuard ────────────────────────────────────────────────
systemctl enable wg-quick@wg0
systemctl start  wg-quick@wg0

# ── UFW firewall ──────────────────────────────────────────────────────────────
ufw --force reset
ufw default deny incoming
ufw default allow outgoing

# Allow SSH
ufw allow 22/tcp

# Allow WireGuard
ufw allow ${wireguard_port}/udp

# Allow forwarding through UFW (required for NAT)
sed -i 's/^DEFAULT_FORWARD_POLICY="DROP"/DEFAULT_FORWARD_POLICY="ACCEPT"/' /etc/default/ufw

# Enable UFW without IPv6 prompt
ufw --force enable

# ── Harden SSH ────────────────────────────────────────────────────────────────
sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/'         /etc/ssh/sshd_config
sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#*MaxAuthTries.*/MaxAuthTries 3/'                /etc/ssh/sshd_config
systemctl restart ssh

# ── fail2ban – protect SSH ────────────────────────────────────────────────────
cat > /etc/fail2ban/jail.d/ssh.conf <<'EOF'
[sshd]
enabled  = true
port     = ssh
maxretry = 5
bantime  = 3600
EOF
systemctl enable fail2ban
systemctl start  fail2ban

echo "=== Bootstrap complete at $(date -u) ==="
