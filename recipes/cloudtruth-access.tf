module "grant-cloudtruth-access" {
  source = "github.com/cloudtruth/terraform-cloudtruth-access"
  role_name = "cloudtruth"
  external_id = ""
  account_ids = ["811566399652", "760722967169"]
  services_enabled = ["s3", "ssm"]
  s3_resources     = [
    "arn:aws:s3:::ctdemo-production-sample-data",
    "arn:aws:s3:::ctdemo-production-sample-data/*",
    "arn:aws:s3:::ctdemo-ops-terraform-state",
    "arn:aws:s3:::ctdemo-ops-terraform-state/*"
  ]
}
