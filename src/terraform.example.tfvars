# ─────────────────────────────────────────────────────────────────────────────
# terraform.tfvars  —  DO NOT COMMIT THIS FILE TO GIT
# Add terraform.tfvars to your .gitignore
# ─────────────────────────────────────────────────────────────────────────────

# Region: Mumbai
aws_region   = "ap-south-1"
project_name = "wg-proxy"

# ── Generate WireGuard keys before running tofu apply ────────────────────────
#
# On Linux/macOS (requires wireguard-tools):
#   wg genkey | tee server.key | wg pubkey > server.pub
#   wg genkey | tee client.key | wg pubkey > client.pub
#
# On Windows (via WireGuard app or WSL):
#   wg genkey > server.key && wg pubkey < server.key > server.pub
#   wg genkey > client.key && wg pubkey < client.key > client.pub
#
# Then paste the contents of each file below.
# ─────────────────────────────────────────────────────────────────────────────

wg_server_private_key = "PASTE_SERVER_PRIVATE_KEY_HERE"
wg_server_public_key  = "PASTE_SERVER_PUBLIC_KEY_HERE"
wg_client_private_key = "PASTE_CLIENT_PRIVATE_KEY_HERE"
wg_client_public_key  = "PASTE_CLIENT_PUBLIC_KEY_HERE"

# ── WireGuard tunnel IPs (defaults are fine, change if they clash) ────────────
wg_server_ipv4 = "10.200.0.1/24"
wg_server_ipv6 = "fd86:ea04:1115::1/64"
wg_client_ipv4 = "10.200.0.2/32"
wg_client_ipv6 = "fd86:ea04:1115::2/128"

wireguard_port = 51820

# ── SSH access restriction (recommended: set to your own IP) ─────────────────
# allowed_ipv4_cidr = "203.0.113.0/32"   # your home/office IPv4
# allowed_ipv6_cidr = "2001:db8::/128"   # your home/office IPv6

common_tags = {
  Project   = "wg-proxy"
  ManagedBy = "opentofu"
  Region    = "ap-south-1"
}
