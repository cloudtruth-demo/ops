data "aws_eks_cluster" "cluster" {
  name = var.cluster_name
}

data "aws_caller_identity" "current" {
}

locals {
  issuer_url = data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer
  issuer_hostpath = replace(local.issuer_url, "/^https?:///", "")
  provider_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${local.issuer_hostpath}"
}


data "template_file" "assume-role-policy" {
  template = file("${path.module}/templates/trust-policy-iam-service-account.tmpl.json")

  vars = {
    provider_arn = local.provider_arn
    issuer_hostpath = local.issuer_hostpath
    service_account = var.name
    namespace = var.namespace
  }
}

resource "aws_iam_role" "role" {
  name = var.name
  assume_role_policy = data.template_file.assume-role-policy.rendered
}

resource "kubernetes_service_account" "account" {
  automount_service_account_token = var.automount_token
  metadata {
    name = var.name
    namespace = var.namespace

    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.role.arn
    }
  }
}
