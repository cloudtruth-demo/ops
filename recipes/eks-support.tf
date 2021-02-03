data "terraform_remote_state" "default" {
  backend = "s3"
  config = {
    bucket = var.backend["bucket"]
    key    = "default-terraform.tfstate"
    region = var.backend["region"]
  }
}

data "aws_eks_cluster" "services" {
  name = data.terraform_remote_state.default.outputs.eks_clusters.services.cluster_name
}

data "aws_eks_cluster_auth" "services" {
  name = data.terraform_remote_state.default.outputs.eks_clusters.services.cluster_name
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.services.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.services.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.services.token
  load_config_file       = false
}

provider "helm" {
  kubernetes {
    host     = data.aws_eks_cluster.services.endpoint
    token                  = data.aws_eks_cluster_auth.services.token
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.services.certificate_authority[0].data)
  }
}

resource "helm_release" "kubernetes-dashboard" {
  repository = "https://kubernetes.github.io/dashboard/"
  chart = "kubernetes-dashboard"
  name  = "kubernetes-dashboard"
  create_namespace = true
  namespace = "kubernetes-dashboard"

  set {
    name  = "metrics-server.enabled"
    value = true
  }

  set {
    name  = "metricsScraper.enabled"
    value = true
  }

}

resource "kubernetes_cluster_role_binding" "kubernetes-dashboard-permissions" {
  depends_on = [helm_release.kubernetes-dashboard]

  metadata {
    name = "kubernetes-dashboard"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "kubernetes-dashboard"
    namespace = "kubernetes-dashboard"
  }
}

module "eks-service-account-load-balancer" {
  source = "../modules/eks-iam-service-account"
  namespace = "kube-system"
  name = "${var.local_name_prefix}eks-service-account-load-balancer"
  cluster_name = data.terraform_remote_state.default.outputs.eks_clusters.services.cluster_name
  automount_token = true
}

resource "aws_iam_role_policy" "eks-service-account-load-balancer" {
  role       = module.eks-service-account-load-balancer.role
  name = "${var.local_name_prefix}allow-load-balancer-management"
  policy = file("../templates/policy-eks-load-balancer.json")
}

resource "helm_release" "aws-load-balancer-controller" {
  repository = "https://aws.github.io/eks-charts/"
  chart = "aws-load-balancer-controller"
  name  = "aws-load-balancer-controller"
  namespace = "kube-system"

  set {
    name  = "clusterName"
    value = data.terraform_remote_state.default.outputs.eks_clusters.services.cluster_name
  }

  set {
    name  = "serviceAccount.create"
    value = false
  }

  set {
    name  = "serviceAccount.name"
    value = module.eks-service-account-load-balancer.name
  }

  set {
    name  = "region"
    value = var.region
  }

  set {
    name  = "vpcId"
    value = data.terraform_remote_state.default.outputs.vpc_id
  }

}

module "eks-service-account-external-dns" {
  source = "../modules/eks-iam-service-account"
  namespace = "kube-system"
  name = "${var.local_name_prefix}eks-service-account-external-dns"
  cluster_name = data.terraform_remote_state.default.outputs.eks_clusters.services.cluster_name
  automount_token = true
}

resource "aws_iam_role_policy" "eks-service-account-external-dns" {
  role       = module.eks-service-account-external-dns.role
  name = "${var.local_name_prefix}allow-external-dns-management"
  policy = file("../templates/policy-eks-external-dns.json")
}

resource "helm_release" "external-dns" {
  repository = "https://charts.bitnami.com/bitnami/"
  chart = "external-dns"
  name  = "external-dns"
  namespace = "kube-system"

  set {
    name  = "serviceAccount.create"
    value = false
  }

  set {
    name  = "serviceAccount.name"
    value = module.eks-service-account-external-dns.name
  }

  set {
    name  = "provider"
    value = "aws"
  }

  set {
    name  = "aws.region"
    value = var.region
  }

  set {
    name  = "sources"
    value = "{service,ingress}"
  }

  set {
    name  = "policy"
    value = "sync"
  }

  set {
    name  = "domainFilters"
    value = "{${var.domain}}"
  }

}

resource "helm_release" "kubetruth" {
  repository = "https://packages.cloudtruth.com/charts/"
  chart = "kubetruth"
  name  = "kubetruth"
  namespace = "default"

  set {
    name  = "appSettings.environment"
    value = var.atmos_env
  }

  set {
    name  = "appSettings.apiKey"
    value = var.cloudtruth_api_key
  }

  set {
    name  = "appSettings.keyPrefix"
    value = "{service}"
  }

}
