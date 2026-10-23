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
- `sentinel.tf` — Waits for the DC to report ready (see Sentinel Wait)  
- `scripts/wait-for-sentinel.sh` — Sentinel poller, run locally by Terraform  

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
| `dhcp_update`       | bool   | `true`     | Associate a DHCP option set pointing the VPC's DNS at the DC. |
| `sentinel_timeout`  | number | `1200`     | Seconds to wait for the DC to report ready before failing the apply. |

---

## Outputs

- `dns_server` — Active Directory DNS hostname  
- `ready` — resolves once the DC has finished bootstrapping; use it in `depends_on`  
- `sentinel_parameter` — SSM parameter holding the bootstrap status  

---

## Sentinel Wait

Rather than sleeping a fixed time, the module waits for the DC to report that
it is actually done - and fails the apply at once if the bootstrap aborts:

1. Terraform creates the SSM parameter `/mini-ad/<netbios>/<vpc-id>/status` with the value
   `pending`. The VPC ID keeps two deployments that reuse a NetBIOS name in different
   VPCs from sharing one parameter.
2. The bootstrap script writes milestones (`progress:<instance-id>:<stage>`), or
   `failed:<instance-id>:line N: <command>` if any step aborts.
3. The script ends in a reboot. On the next boot, `mini-ad-ready.service`
   waits until Samba answers DNS and LDAP, writes `ready:<instance-id>`,
   and disables itself.
4. Terraform polls the parameter and finishes on `ready`, or fails the
   apply immediately on `failed`, printing the failing line.

Every value carries the instance ID, so a replaced DC is waited on afresh and
never satisfied by its predecessor's status. Failure messages report the
command as written (`"$PASSWORD"`), never the expanded value.

Requirements and limits:

- The machine running Terraform needs `bash` and the AWS CLI, with
  `ssm:GetParameter`, `ssm:GetParameterHistory` and `ec2:DescribeInstances`.
- A failure before the bootstrap installs the AWS CLI cannot be reported;
  the wait then fails at `sentinel_timeout` instead.
- A DC launched before its status parameter existed - a deployment created
  with an earlier version of this module - never runs the reporting code
  (cloud-init runs user data once). The wait detects this and passes
  straight through.

## Changes Ignored on a Running DC

The DC instance ignores changes to `ami` and `user_data`:

- **`ami`** tracks Canonical's *current* Ubuntu 24.04 image, so without this
  every Ubuntu release would replace the DC - a brand-new domain that orphans
  every machine joined to the old one.
- **`user_data`** runs once, on first boot. Changing it on a running DC only
  stops and starts the instance; the script never runs again. Seed users and
  passwords therefore apply only to a new DC.

To rebuild the DC deliberately with the current image and script:

```bash
terraform apply -replace='module.mini_ad.aws_instance.mini_ad_dc_instance'
```

---

## Limitations

- Single domain controller (no HA).  
- Exposes required AD ports (limit access for security).  
- Not suitable for production workloads.  
