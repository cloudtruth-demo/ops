module "grant-cloudtruth-access" {
  source = "github.com/cloudtruth/terraform-cloudtruth-access"
  role_name = "cloudtruth"
  external_id = "07e76c9c-cf3a-41ce-87bc-6d1e5a3a0af6,edd14b2d-5b95-4f69-b3c5-d78447d86926,c47fd6ce-0953-4b39-8c99-96afea2624ee"
  account_ids = ["811566399652", "760722967169"]
  services_enabled = ["s3", "ssm"]
  s3_resources     = [
    "arn:aws:s3:::ctdemo-production-sample-data",
    "arn:aws:s3:::ctdemo-production-sample-data/*",
    "arn:aws:s3:::ctdemo-ops-terraform-state",
    "arn:aws:s3:::ctdemo-ops-terraform-state/*",
    "arn:aws:s3:::ctdemo-development-terraform-state",
    "arn:aws:s3:::ctdemo-development-terraform-state/*",
    "arn:aws:s3:::ctdemo-production-terraform-state",
    "arn:aws:s3:::ctdemo-production-terraform-state/*"
  ]
}
