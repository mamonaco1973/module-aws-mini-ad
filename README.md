# AWS Mini Active Directory Module

This Terraform module deploys a **lightweight Active Directory Domain Controller** on AWS using **Samba 4** on Ubuntu.  
It’s designed for **labs, demos, and development environments** where you need AD functionality without the overhead and cost of AWS Directory service.

⚠️ **Note**: This module is *not* production-ready. It’s intended for testing, prototyping, and training purposes.

---

## Features

- Provisions an **Ubuntu EC2 instance** running Samba 4 as a Domain Controller.
- Configures **Active Directory and DNS**.
- Creates **IAM roles** required for secrets access and instance management.
- Sets up **security groups** with AD/DC firewall rules.
- Uses **user-data bootstrap scripts** (`mini-ad.sh.template`) to automate provisioning.
- Supports **seed users and groups** via `users.json.template`.
- Configures **DHCP option set** for the input VPC.

---

## Module Structure

- `dc.tf` — Domain Controller instance and configuration  
- `roles.tf` — IAM roles and policies  
- `security.tf` — Security groups for AD/DC traffic  
- `variables.tf` — Input variable definitions  
- `outputs.tf` — Outputs (e.g., IP, domain name)  
- `scripts/mini-ad.sh.template` — Bootstrap script for Samba DC  
- `scripts/users.json.template` — Example users and groups  

---

## Usage Example

Here’s how you can use the module in your Terraform configuration:

```hcl
provider "aws" {
  region = "us-east-1"
}

module "mini_ad" {
  source = "github.com/mamonaco1973/module-aws-mini-ad"

  # Required variables
  netbios            = "MCLOUD"
  dns_zone           = "mcloud.mikecloud.com"
  realm              = "MCLOUD.MIKECLOUD.COM"
  ad_admin_password  = "ChangeMe123!"
  vpc_id             = "vpc-123456"
  subnet_id          = "subnet-123456"

  # Optional
  instance_type      = "t3.small"
  user_base_dn       = "CN=Users,DC=mcloud,DC=mikecloud,DC=com"
  users_json         = "" # custom JSON string of seed users/groups
}
```

Run:

```bash
terraform init
terraform apply
```

---

## Parameters

| Name                | Type   | Default    | Description |
|---------------------|--------|------------|-------------|
| `dns_zone`          | string | —          | DNS zone for the Samba AD domain (e.g., `mcloud.mikecloud.com`). |
| `realm`             | string | —          | Kerberos realm (typically uppercase form of DNS zone). |
| `netbios`           | string | —          | NetBIOS short name for the domain. |
| `user_base_dn`      | string | —          | Base DN for user objects in LDAP (e.g., `CN=Users,DC=mcloud,DC=mikecloud,DC=com`). |
| `instance_type`     | string | `t3.small` | Size of the AD DC EC2 instance. |
| `ad_admin_password` | string | —          | Password for the AD Administrator and Admin account used in Samba bootstrap. *(Sensitive)* |
| `subnet_id`         | string | —          | ID of the subnet where the EC2 instance will be attached. |
| `vpc_id`            | string | —          | ID of the VPC where the AD DC will be deployed and DHCP option set updated. |
| `users_json`        | string | `""`       | Pre-rendered JSON string containing user account definitions (from `users.json.template`). |

---

## Outputs

- `dns_server` — Active Directory DNS hostname  

---

## Limitations

- Single domain controller (no HA).  
- Exposes required AD ports (limit access for security).  
- Not suitable for production workloads.  
