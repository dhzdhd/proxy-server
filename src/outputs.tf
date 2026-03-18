output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.server.id
}

output "elastic_ip_v4" {
  description = "Static public IPv4 (Elastic IP) — use this as your WireGuard endpoint"
  value       = aws_eip.server.public_ip
}

output "instance_ipv6" {
  description = "Public IPv6 address of the instance"
  value       = aws_instance.server.ipv6_addresses[0]
}

output "ssh_command_ipv4" {
  description = "SSH via IPv4 EIP"
  value       = "ssh -i ${var.project_name}.pem ubuntu@${aws_eip.server.public_ip}"
}

output "ssh_command_ipv6" {
  description = "SSH via IPv6"
  value       = "ssh -6 -i ${var.project_name}.pem ubuntu@${aws_instance.server.ipv6_addresses[0]}"
}

output "private_key_path" {
  description = "Path to the downloaded SSH private key"
  value       = local_sensitive_file.private_key.filename
}

output "wg_client_config_path" {
  description = "Path to the rendered WireGuard client config"
  value       = local_file.wg_client_config.filename
}

output "ami_used" {
  description = "Ubuntu ARM64 AMI resolved at plan time"
  value       = "${data.aws_ami.ubuntu_arm64.name} (${data.aws_ami.ubuntu_arm64.id})"
}

output "wireguard_endpoint" {
  description = "WireGuard endpoint to put in your client config"
  value       = "${aws_eip.server.public_ip}:${var.wireguard_port}"
}
