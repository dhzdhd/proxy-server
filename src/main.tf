terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

resource "tls_private_key" "ssh" {
  algorithm = "ED25519"
}

resource "aws_key_pair" "generated" {
  key_name   = "${var.project_name}-key"
  public_key = tls_private_key.ssh.public_key_openssh

  tags = merge(var.common_tags, { Name = "${var.project_name}-key" })
}

resource "local_sensitive_file" "private_key" {
  content         = tls_private_key.ssh.private_key_openssh
  filename        = "${path.module}/${var.project_name}.pem"
  file_permission = "0600"
}

data "aws_ami" "ubuntu_arm64" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-arm64-server-*"]
  }

  filter {
    name   = "architecture"
    values = ["arm64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

resource "aws_vpc" "main" {
  cidr_block                       = "10.0.0.0/16"
  assign_generated_ipv6_cidr_block = true
  enable_dns_support               = true
  enable_dns_hostnames             = true

  tags = merge(var.common_tags, { Name = "${var.project_name}-vpc" })
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.common_tags, { Name = "${var.project_name}-igw" })
}

resource "aws_subnet" "public" {
  vpc_id                          = aws_vpc.main.id
  cidr_block                      = "10.0.1.0/24"
  ipv6_cidr_block                 = cidrsubnet(aws_vpc.main.ipv6_cidr_block, 8, 1)
  availability_zone               = "${var.aws_region}a"
  assign_ipv6_address_on_creation = true
  map_public_ip_on_launch         = false
  tags                            = merge(var.common_tags, { Name = "${var.project_name}-public-subnet" })
}


resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.main.id
  }

  tags = merge(var.common_tags, { Name = "${var.project_name}-public-rt" })
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "instance" {
  name        = "${var.project_name}-sg"
  description = "SSH and WireGuard ingress; all egress"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH IPv4"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ipv4_cidr]
  }

  ingress {
    description      = "SSH IPv6"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    ipv6_cidr_blocks = [var.allowed_ipv6_cidr]
  }

  ingress {
    description = "WireGuard UDP IPv4"
    from_port   = var.wireguard_port
    to_port     = var.wireguard_port
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description      = "WireGuard UDP IPv6"
    from_port        = var.wireguard_port
    to_port          = var.wireguard_port
    protocol         = "udp"
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "ICMPv6"
    from_port        = -1
    to_port          = -1
    protocol         = "58"
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = merge(var.common_tags, { Name = "${var.project_name}-sg" })
}

resource "aws_instance" "server" {
  ami                         = data.aws_ami.ubuntu_arm64.id
  instance_type               = "t4g.micro"
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.instance.id]
  key_name                    = aws_key_pair.generated.key_name
  associate_public_ip_address = false
  ipv6_address_count          = 1
  source_dest_check           = false

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 8
    delete_on_termination = true
    encrypted             = true
  }

  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    http_endpoint               = "enabled"
    http_protocol_ipv6          = "enabled"
  }

  user_data = base64encode(templatefile("${path.module}/setup.sh", {
    wireguard_port        = var.wireguard_port
    wg_server_private_key = var.wg_server_private_key
    wg_client_public_key  = var.wg_client_public_key
    wg_server_ipv4        = var.wg_server_ipv4
    wg_server_ipv6        = var.wg_server_ipv6
    wg_client_ipv4        = var.wg_client_ipv4
    wg_client_ipv6        = var.wg_client_ipv6
  }))

  tags = merge(var.common_tags, { Name = "${var.project_name}-server" })

  depends_on = [aws_internet_gateway.main]
}

resource "aws_eip" "server" {
  domain   = "vpc"
  instance = aws_instance.server.id

  tags       = merge(var.common_tags, { Name = "${var.project_name}-eip" })
  depends_on = [aws_internet_gateway.main]
}

resource "local_file" "wg_client_config" {
  content = templatefile("${path.module}/wireguard.conf", {
    wg_client_private_key = var.wg_client_private_key
    wg_client_ipv4        = var.wg_client_ipv4
    wg_client_ipv6        = var.wg_client_ipv6
    wg_server_public_key  = var.wg_server_public_key
    server_ipv4           = aws_eip.server.public_ip
    server_ipv6           = aws_instance.server.ipv6_addresses[0]
    wireguard_port        = var.wireguard_port
  })
  filename        = "${path.module}/wg0-client.conf"
  file_permission = "0600"
}
