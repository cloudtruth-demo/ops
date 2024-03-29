variable "secret_config" {
  description = "The secret config hash"
  type        = map(string)
}

variable "name" {
  description = "The name indicating use of the secret access"
}

variable "roles" {
  description = "The roles to grant secret access to"
}

variable "keys" {
  description = "The secret keys to allow access for"
  type        = list(string)
}

locals {
  ssm_secrets = var.secret_config["type"] == "ssm" ? 1 : 0
  s3_secrets  = var.secret_config["type"] == "s3" ? 1 : 0

  // Remove excess slashes, and ensure leading/trailing slash so we can easily sub in the
  // arn even when blank
  raw_path_prefix   = lookup(var.secret_config, "prefix", "")
  clean_path_prefix = join("/", compact(split("/", trimspace(local.raw_path_prefix))))
  path_prefix       = "${length(local.clean_path_prefix) > 0 ? "/" : ""}${local.clean_path_prefix}"
  bucket            = lookup(var.secret_config, "bucket", "")
  account_id        = data.aws_caller_identity.current.account_id
  region            = data.aws_region.current.name
}

data "aws_caller_identity" "current" {
}

data "aws_region" "current" {
}

data "template_file" "secret-access-policy-s3" {
  template = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject"
      ],
      "Resource": ${jsonencode(
  formatlist(
    "arn:aws:s3:::${local.bucket}${local.path_prefix}/%s",
    var.keys,
  ),
)}
    }
  ]
}
EOF

}

data "template_file" "secret-access-policy-ssm" {
  template = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ssm:GetParameter",
        "ssm:GetParameters"
      ],
      "Resource": ${jsonencode(
  formatlist(
    "arn:aws:ssm:${local.region}:${local.account_id}:parameter${local.path_prefix}/%s",
    var.keys,
  ),
)}
    }
  ]
}
EOF

}

data "template_file" "secret-access-policy" {
  template = local.ssm_secrets == 1 ? data.template_file.secret-access-policy-ssm.rendered : (
  local.s3_secrets == 1 ? data.template_file.secret-access-policy-s3.rendered : "")
}

resource "aws_iam_role_policy" "secret-access" {
  for_each = toset(var.roles)

  name = "${var.name}-secret-access-${each.value}"
  role = each.value

  policy = data.template_file.secret-access-policy.rendered
}

