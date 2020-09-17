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

output "deployer" {
  sensitive = true
  value = {
    access_key = aws_iam_access_key.deployer.*.id
    access_secret = aws_iam_access_key.deployer.*.secret
  }
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

resource "aws_iam_user_policy" "allow-ecs-deploy" {
  count = var.atmos_env == local.ops_env ? 1 : 0

  name = "${var.local_name_prefix}allow-ecs-deploy"
  user = aws_iam_user.deployer[0].name

  policy = file("../templates/policy-deployer-permissions.json")
}
