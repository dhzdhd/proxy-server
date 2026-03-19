# WireGuard VPN Proxy

> [!WARNING]
> This project was designed and built by Claude Sonnet 4.6 under the supervision and direction of dhzdhd

Deploys a **t4g.micro** WireGuard VPN server in your preferred AWS location
that routes all your traffic — including local applications — through
the location exit node with a static public IPv4 (Elastic IP) and a public IPv6 address.

## Architecture

```
Your PC (dual-stack)
  │
  │  WireGuard tunnel (UDP 51820)
  │  ├─ connects over IPv4 EIP  (default)
  │  └─ or over IPv6            (optional, toggle in client config)
  ▼
EC2 t4g.micro
  ├─ Elastic IP  (static IPv4)   ← WireGuard endpoint
  ├─ Public IPv6                 ← alternate endpoint
  └─ NAT / masquerade
       │
       ▼  IPv4 or IPv6
  External servers
```

All traffic from your PC exits from the location.

---

## Prerequisites

| Tool            | Version | Install                                                             |
| --------------- | ------- | ------------------------------------------------------------------- |
| OpenTofu        | ≥ 1.6   | https://opentofu.org/docs/intro/install/                            |
| AWS CLI         | ≥ 2.x   | https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html |
| wireguard-tools | any     | `apt install wireguard-tools` / `brew install wireguard-tools`      |
| AWS credentials | —       | `aws configure`                                                     |

For the AWS Configuration -

- Run `aws configure`
- It'll prompt for:
  ```
  AWS Access Key ID:     AKIA...
  AWS Secret Access Key: xxxxxx
  Default region:        AWS location (like ap-south-1)
  Default output format: json
  ```
- Get your keys from AWS Console → IAM → Users → your user → Security credentials → Create access key.

---

## Step-by-Step Setup

### 1. Generate WireGuard keys

Run these commands once. Keep the `.key` files secret — never commit them.

```bash
# Server keypair
wg genkey | tee server.key | wg pubkey > server.pub

# Client (your PC) keypair
wg genkey | tee client.key | wg pubkey > client.pub

cat server.key server.pub client.key client.pub
```

### 2. Fill in terraform.tfvars

```bash
# Edit terraform.tfvars and paste all four keys
cp terraform.tfvars.example terraform.tfvars
```

Add `terraform.tfvars` and `*.key` to your `.gitignore`.

### 3. Deploy

```bash
tofu init
tofu plan      # review — should be ~13 resources
tofu apply
```

### 4. After apply — check outputs

```
elastic_ip_v4           = "13.x.x.x"
instance_ipv6           = "2406:da1a:xxxx::1"
ssh_command_ipv4        = "ssh -i wg-proxy.pem ubuntu@13.x.x.x"
private_key_path        = "./wg-proxy.pem"
wg_client_config_path   = "./wg0-client.conf"
wireguard_endpoint      = "13.x.x.x:51820"
```

Two files are written locally:

- `wg-proxy.pem` — SSH private key (chmod 600)
- `wg0-client.conf` — ready-to-use WireGuard client config

### 5. Wait for WireGuard to install (~2 min)

The server installs WireGuard via `user_data` on first boot. Check progress:

```bash
ssh -i wg-proxy.pem ubuntu@<elastic-ip>
tail -f /var/log/user-data.log
# Wait for: "=== Bootstrap complete ==="
```

### 6. Install WireGuard on your PC and connect

**Linux / macOS:**

```bash
sudo cp wg0-client.conf /etc/wireguard/wg0.conf
sudo wg-quick up wg0

# Verify — your public IP should now show the location you entered for the EC2 instance
curl -6 https://ifconfig.co   # IPv6 exit
curl -4 https://ifconfig.co   # IPv4 exit (server's EIP)
```

**Windows:**

1. Install [WireGuard for Windows](https://www.wireguard.com/install/)
2. Open WireGuard → Add Tunnel → Import from file → select `wg0-client.conf`
3. Click Activate

**Android / iOS:**

1. Install WireGuard app
2. Scan the QR code: `qrencode -t ansiutf8 < wg0-client.conf`

---

## Tear Down

```bash
tofu destroy
```

This removes all AWS resources. The `.pem` and `wg0-client.conf` files remain locally.
