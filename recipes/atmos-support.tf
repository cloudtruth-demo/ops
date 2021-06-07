
data "template_file" "policy-logs-bucket" {
  vars = {
    bucket     = var.logs_bucket
    account_id = var.account_ids[var.atmos_env]
  }

  template = file("../templates/policy-logs-bucket.tmpl.json")
}

resource "aws_s3_bucket" "logs" {
  bucket        = var.logs_bucket
  acl           = "log-delivery-write"
  force_destroy = var.force_destroy_buckets

  lifecycle_rule {
    prefix  = ""
    enabled = true

    expiration {
      days = 14
    }
  }

  // ELB: https://docs.aws.amazon.com/elasticloadbalancing/latest/classic/enable-access-logs.html#attach-bucket-policy
  policy = data.template_file.policy-logs-bucket.rendered

  tags = {
    Env    = var.atmos_env
    Source = "atmos"
  }
}

output "atmos_yml" {
  sensitive = true
  value     = <<-EOF
org: "${var.org}"

environments:
${join("\n", formatlist("  %s:\n    account_id: \"%s\"\n", keys(var.account_ids), values(var.account_ids)))}

providers:
  aws:
    region: "${var.region}"
    auth:
      # we don't use assume role for demo setup
      bypass: true
EOF
}
