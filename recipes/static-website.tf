variable "website_bucket" {
  description = "The bucket for hosting a static website"
}

module "static-website-app" {
  source = "../modules/static-website"

  atmos_env          = var.atmos_env
  global_name_prefix = var.global_name_prefix
  local_name_prefix  = var.local_name_prefix

  name = "app"

  aliases = ["app.${var.domain}"]

  zone_id               = module.dns.public_zone_id
  certificate_arn       = module.wildcart-cert.certificate_arn
  site_bucket           = var.website_bucket
  logs_bucket           = var.logs_bucket
  force_destroy_buckets = var.force_destroy_buckets
  wait_for_deployment   = false

  custom_error_responses = [
    {
      error_code            = 404
      response_code         = 200
      response_page_path    = "/index.html"
      error_caching_min_ttl = 0
    }
  ]

}

data "template_file" "policy-deploy-static-website" {
  vars = {
    site_bucket_arn = module.static-website-app.site_bucket_arn
    site_cdn_arn    = module.static-website-app.distribution_arn
  }

  template = file("../templates/policy-deploy-static-website.tmpl.json")
}

resource "aws_iam_user_policy" "website-deploy-s3-cdn-access" {
  name = "${var.local_name_prefix}website-deploy-s3-cdn-access"
  user = local.deployer_user

  policy = data.template_file.policy-deploy-static-website.rendered
}
