locals {
  ns_msg = <<-EOF
Certificate validation will not succeed until you register the
${var.domain} zone nameservers with your registrar

${join("\n", var.zone_name_servers)}
EOF


  ns_ipc = jsonencode(
    {
      "action"  = "notify"
      "message" = local.ns_msg
      "modal"   = "true"
    },
  )

  ipc_cmd = var.register_nameservers_notice ? "$ATMOS_IPC_CLIENT '${local.ns_ipc}'" : ":"
}

// domain and *.domain end up getting collapsed into a single domain_validation_options
resource "aws_acm_certificate" "primary" {
  domain_name               = var.domain
  subject_alternative_names = var.alternative_names
  validation_method         = "DNS"

  provisioner "local-exec" {
    command    = local.ipc_cmd
    on_failure = continue
  }

  tags = {
    Name        = "${var.local_name_prefix}primary-cert"
    Environment = var.atmos_env
    Source      = "atmos"
  }
}

locals {
  wildcard  = "*.${var.domain}"
  all_names = concat([var.domain], var.alternative_names)
  names_without_wildcard = compact(
    split(",", replace(join(",", local.all_names), local.wildcard, "")),
  )
  validated_domains = [for x in aws_acm_certificate.primary.domain_validation_options: x if contains(local.names_without_wildcard, x["domain_name"])]
}

resource "aws_route53_record" "cert_validation" {
  count = length(local.validated_domains)

  name    = local.validated_domains[count.index]["resource_record_name"]
  type    = local.validated_domains[count.index]["resource_record_type"]
  zone_id = var.zone_id

  records = [local.validated_domains[count.index]["resource_record_value"]]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "cert" {
  certificate_arn         = aws_acm_certificate.primary.arn
  validation_record_fqdns = aws_route53_record.cert_validation.*.fqdn
}

