# ------------------------------------------------------------------------------
# Automatic unique suffix (stable per deployment/state)
# ------------------------------------------------------------------------------
resource "random_id" "iam_suffix" {
  byte_length = 3 # 6 hex chars (e.g., a1b2c3) - short but plenty unique
}

locals {
  iam_id = "mini-ad-${lower(var.netbios)}-${random_id.iam_suffix.hex}"
}

# ------------------------------------------------------------------------------
# IAM Role for SSM-managed EC2
# ------------------------------------------------------------------------------
resource "aws_iam_role" "ec2_ssm_role" {
  name = "tf-role-${local.iam_id}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "attach_ssm_core" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "attach_ssm_full" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMFullAccess"
}

resource "aws_iam_role_policy_attachment" "attach_secrets_rw" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
}

# ------------------------------------------------------------------------------
# Instance Profile
# ------------------------------------------------------------------------------
resource "aws_iam_instance_profile" "ec2_ssm_profile" {
  name = "tf-profile-${local.iam_id}"
  role = aws_iam_role.ec2_ssm_role.name
}
