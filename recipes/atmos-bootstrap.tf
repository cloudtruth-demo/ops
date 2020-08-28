// This file should be kept as minimal as possible - basically just enough for
// terraform to run, and so usually just contains the state storage, secret
// storage, lock table, and cross-account access role

data "template_file" "policy-backend-bucket" {
  vars = {
    bucket              = var.backend["bucket"]
  }

  template = file("../templates/policy-backend-bucket.tmpl.json")
}

resource "aws_s3_bucket" "backend" {
  bucket        = var.backend["bucket"]
  acl           = "private"
  force_destroy = var.force_destroy_buckets

  versioning {
    enabled = true
  }

  policy = data.template_file.policy-backend-bucket.rendered

  tags = {
    Env    = var.atmos_env
    Source = "atmos"
  }
}

resource "aws_dynamodb_table" "backend-lock-table" {
  name           = var.backend["dynamodb_table"]
  read_capacity  = 1
  write_capacity = 1
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Env    = var.atmos_env
    Source = "atmos"
  }
}
