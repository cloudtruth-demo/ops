locals {
  deployer_user = "${var.org_prefix}deployer"
}

resource "aws_iam_user" "deployer" {
  count = var.atmos_env == local.ops_env ? 1 : 0

  name = local.deployer_user
  path = "/"
}

resource "aws_iam_access_key" "deployer" {
  count = var.atmos_env == local.ops_env ? 1 : 0

  user = aws_iam_user.deployer[0].name
}

variable "display_deployer" {
  description = "Set to 1 to display the aws keys for the deployer user, e.g. TF_VAR_display_deployer=1 atmos -e ops plan"
  default     = 0
}

// Set enabled=1 to display deployer keys to get them for your CI system
module "display-access-keys" {
  source  = "../modules/atmos-ipc"
  action  = "notify"
  enabled = var.display_deployer * (var.atmos_env == local.ops_env ? 1 : 0)

  params = {
    inline  = "true"
    message = <<-EOF
    deployer-access-key: ${join("", aws_iam_access_key.deployer.*.id)}
    deployer-access-secret: ${join("", aws_iam_access_key.deployer.*.secret)}
EOF

  }
}
