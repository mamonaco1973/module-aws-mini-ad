# ==================================================================================================
# Variables for mini-ad module
# Purpose:
#   - Define all input parameters required for provisioning the Samba AD DC EC2
# ==================================================================================================

variable "dns_zone" {
  description = "DNS zone for the Samba AD domain (e.g., mcloud.mikecloud.com)."
  type        = string
}

variable "realm" {
  description = "Kerberos realm (typically uppercase form of DNS zone)."
  type        = string
}

variable "netbios" {
  description = "NetBIOS short name for the domain."
  type        = string
}

variable "user_base_dn" {
  description = "Base DN for user objects in LDAP (e.g., CN=Users,DC=mcloud,DC=mikecloud,DC=com)."
  type        = string
}

variable "instance_type" {
  description = "Size of the AD DC EC2 instance."
  type        = string
  default     = "t3.small"
}

variable "ad_admin_password" {
  description = "Password for the AD Administrator and Admin account used in Samba bootstrap."
  type        = string
  sensitive   = true

   validation {
    condition     = !can(regex("^\\-", var.ad_admin_password))
    error_message = "The AD admin password cannot start with a dash (-)."
  }
}

variable "subnet_id" {
  description = "ID of the subnet where the EC2 instance will be attached."
  type        = string
}

variable "vpc_id" {
  description = "ID of the Virtual Private Cloud (VPC) for DNS server updates."
  type        = string
}

variable "users_json" {
  description = "Pre-rendered JSON string containing user account definitions (from users.json.template)."
  type        = string
  default     = ""
}

variable "dhcp_update" {
  description = "Update the dhcp settings for the specified VPC"
  type        = bool
  default     = true
}

variable "wait_strategy" {
  description = <<-EOT
    How Terraform waits for the DC to finish bootstrapping before associating
    the VPC DHCP options:
      "sleep"    - fixed 300 s wait (original behaviour, the default).
      "sentinel" - poll an SSM parameter the DC writes; finishes as soon as
                   Samba answers after the final reboot, and fails fast with
                   the failing line if the bootstrap aborts. Requires bash
                   and the AWS CLI on the machine running Terraform.
  EOT
  type        = string
  default     = "sleep"

  validation {
    condition     = contains(["sleep", "sentinel"], var.wait_strategy)
    error_message = "wait_strategy must be \"sleep\" or \"sentinel\"."
  }
}

variable "sentinel_timeout" {
  description = "Seconds to wait for the sentinel to report ready before failing (wait_strategy = \"sentinel\" only)."
  type        = number
  default     = 1200
}
