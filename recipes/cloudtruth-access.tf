module "grant-cloudtruth-access" {
  source = "github.com/cloudtruth/terraform-cloudtruth-access"
  role_name = "cloudtruth"
  external_id = ""
  account_ids = ["811566399652", "760722967169"]
  services_enabled = ["s3", "ssm"]
}
