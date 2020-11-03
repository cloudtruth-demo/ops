// The eks cluster has to be provisioned in a separate apply to that of the use
// of the kubernetes provider, so we do so in the bootstrap recipe group, with
// outputs for sharing data via remote state

module "eks-services" {
  source = "../modules/eks-fargate"

  atmos_env = var.atmos_env
  global_name_prefix = var.global_name_prefix
  local_name_prefix = var.local_name_prefix
  region = var.region

  name = "services"
  namespaces = ["default", "kubernetes-dashboard"]
  kubernetes_version = "1.18"

  vpc_id = module.vpc.vpc_id
  cluster_subnet_ids = concat(module.vpc.private_subnet_ids, module.vpc.public_subnet_ids)
  profile_subnet_ids = module.vpc.private_subnet_ids
}

// If coredns pods didn't start cleanly after being patched:
// atmos -e <env> auth_exec kubectl get pods -o wide --all-namespaces
// you'll need to run:
// atmos -e <env> auth_exec kubectl -n kube-system rollout restart deployment/coredns

data "external" "setup_kube_config" {
  program = [
    "atmos", "tfutil", "jsonify",
    "bash", "-c", "KUBECONFIG=<(cat $HOME/.kube/config):<(echo '${module.eks-services.kubecfg}') kubectl config view --flatten > $HOME/.kube/aws_config && mv -f $HOME/.kube/aws_config $HOME/.kube/config "
  ]
}

output "eks_clusters" {
  sensitive = true
  value = {
    services = {
      cluster_name = module.eks-services.cluster_name
    }
  }
}
