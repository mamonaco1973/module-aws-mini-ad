
output "dns_server" {
  description = "DNS server IP address for the mini-ad deployment."
  value       = aws_instance.mini_ad_dc_instance.private_ip
}

output "ready" {
  description = "Resolves once the DC has finished bootstrapping (after the sleep or the sentinel). Use in depends_on."
  value       = local.sentinel_enabled ? terraform_data.wait_for_sentinel[0].id : time_sleep.wait_for_mini_ad[0].id
}

output "sentinel_parameter" {
  description = "SSM parameter the DC reports bootstrap status to (null when wait_strategy = \"sleep\")."
  value       = local.sentinel_enabled ? aws_ssm_parameter.sentinel[0].name : null
}
