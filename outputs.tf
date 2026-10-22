
output "dns_server" {
  description = "DNS server IP address for the mini-ad deployment."
  value       = aws_instance.mini_ad_dc_instance.private_ip
}

output "ready" {
  description = "Resolves once the DC has reported ready. Use in depends_on."
  value       = terraform_data.wait_for_sentinel.id
}

output "sentinel_parameter" {
  description = "SSM parameter the DC reports bootstrap status to."
  value       = aws_ssm_parameter.sentinel.name
}
