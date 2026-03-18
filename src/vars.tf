variable "aws_region" {
  description = "AWS region — Mumbai = ap-south-1"
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Prefix for all resource names and tags"
  type        = string
  default     = "wg-proxy"
}

variable "allowed_ipv4_cidr" {
  description = "IPv4 CIDR allowed to SSH in. Default is open; restrict to your IP for security."
  type        = string
  default     = "0.0.0.0/0"
}

variable "allowed_ipv6_cidr" {
  description = "IPv6 CIDR allowed to SSH in."
  type        = string
  default     = "::/0"
}

variable "wireguard_port" {
  description = "UDP port WireGuard listens on"
  type        = number
  default     = 51820
}

# WireGuard keys
# Generate these ONCE with: wg genkey | tee server.key | wg pubkey > server.pub
#                            wg genkey | tee client.key | wg pubkey > client.pub
variable "wg_server_private_key" {
  description = "WireGuard private key for the SERVER (base64)"
  type        = string
  sensitive   = true
}

variable "wg_server_public_key" {
  description = "WireGuard public key for the SERVER (base64)"
  type        = string
}

variable "wg_client_private_key" {
  description = "WireGuard private key for YOUR PC / client (base64) — written into wg0-client.conf"
  type        = string
  sensitive   = true
}

variable "wg_client_public_key" {
  description = "WireGuard public key for YOUR PC / client (base64)"
  type        = string
}

# These are private addresses INSIDE the WireGuard tunnel — not real IPs.
variable "wg_server_ipv4" {
  description = "IPv4 address of the server inside the WireGuard tunnel"
  type        = string
  default     = "10.200.0.1/24"
}

variable "wg_server_ipv6" {
  description = "IPv6 address of the server inside the WireGuard tunnel"
  type        = string
  default     = "fd86:ea04:1115::1/64"
}

variable "wg_client_ipv4" {
  description = "IPv4 address of your PC inside the WireGuard tunnel"
  type        = string
  default     = "10.200.0.2/32"
}

variable "wg_client_ipv6" {
  description = "IPv6 address of your PC inside the WireGuard tunnel"
  type        = string
  default     = "fd86:ea04:1115::2/128"
}

variable "common_tags" {
  description = "Tags applied to every AWS resource"
  type        = map(string)
  default = {
    Project   = "wg-proxy"
    ManagedBy = "opentofu"
  }
}
