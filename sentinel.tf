# ==================================================================================================
# Sentinel wait
# Purpose:
#   - Wait on the DC's own status report rather than a fixed sleep
#   - Fail the apply quickly, with the failing line, when the bootstrap aborts
#
# Flow:
#   1. Terraform creates the SSM parameter below with the value "pending".
#   2. The bootstrap script (mini-ad.sh.template) overwrites it with
#      progress:<id>:<stage> milestones, or failed:<id>:<detail> on error.
#   3. After the final reboot, mini-ad-ready.service confirms Samba answers DNS
#      and LDAP, then writes ready:<id>.
#   4. terraform_data.wait_for_sentinel polls until it sees ready:<id> or
#      failed:<id> for THIS instance; a predecessor's status never matches.
#
# A DC launched before the parameter existed (a deployment that predates the
# sentinel) never runs the reporting code, since cloud-init runs user data
# once. The poller detects that case and passes straight through.
# ==================================================================================================

# Keyed by VPC as well as domain name: an account can hold several mini-AD
# domains, and two labs that reuse a NetBIOS name in different VPCs would
# otherwise share - and clobber - one parameter.
locals {
  sentinel_param = "/mini-ad/${var.netbios}/${var.vpc_id}/status"
}

resource "aws_ssm_parameter" "sentinel" {
  name        = local.sentinel_param
  description = "Bootstrap status of the mini-ad domain controller for ${var.dns_zone}"
  type        = "String"
  value       = "pending"

  # The DC owns the value after creation.
  lifecycle {
    ignore_changes = [value]
  }
}

# ==================================================================================================
# Poll the sentinel from the machine running Terraform
# - Data sources cannot retry, so a local-exec loop is the only built-in way
#   to block on an external condition.
# - Region is taken from the parameter ARN so the module works with any AWS
#   provider version.
# - triggers_replace re-runs the wait whenever the instance is replaced.
# ==================================================================================================
resource "terraform_data" "wait_for_sentinel" {
  triggers_replace = [aws_instance.mini_ad_dc_instance.id]

  provisioner "local-exec" {
    command = "bash '${path.module}/scripts/wait-for-sentinel.sh'"

    environment = {
      PARAM       = aws_ssm_parameter.sentinel.name
      REGION      = split(":", aws_ssm_parameter.sentinel.arn)[3]
      INSTANCE_ID = aws_instance.mini_ad_dc_instance.id
      TIMEOUT     = var.sentinel_timeout
    }
  }
}
