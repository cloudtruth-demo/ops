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

resource "null_resource" "setup_kube_config" {
  depends_on = [module.eks-services]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<EOF
KUBECONFIG=<(echo '${module.eks-services.kubecfg}'):<(cat $HOME/.kube/config) \
  kubectl config view --flatten > $HOME/.kube/aws_config \
  && mv -f $HOME/.kube/aws_config $HOME/.kube/config
EOF
  }
}

data "template_file" "deployer_rbac" {
  template = <<-EOF
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: deployer-access
  namespace: default
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: edit
subjects:
  - kind: Group
    name: deployer
EOF
}

resource "null_resource" "deployer_rbac" {
  depends_on = [module.eks-services]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<EOF
kubectl --kubeconfig=<(echo '${module.eks-services.kubecfg_tf}') --context terraform \
  apply -f <(echo '${data.template_file.deployer_rbac.rendered}')
EOF
  }
}

# funky formatting, the value of the configmap item is a yaml string
data "template_file" "deployer_permissions_patch" {
  template = <<-EOF
data:
  mapUsers: |
    - userarn: arn:aws:iam::${var.account_ids["ops"]}:user/${var.org_prefix}deployer
      username: deployer
      groups:
        - deployer
EOF
}

resource "null_resource" "deployer_permissions_patch" {
  depends_on = [null_resource.deployer_rbac]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<EOF
kubectl --kubeconfig=<(echo '${module.eks-services.kubecfg_tf}') --context terraform \
  patch configmap/aws-auth \
  --namespace kube-system \
  --type=merge \
  -p='${jsonencode(yamldecode(data.template_file.deployer_permissions_patch.rendered))}'
EOF
  }
}

output "eks_clusters" {
  sensitive = true
  value = {
    services = {
      cluster_name = module.eks-services.cluster_name
      kubecfg = module.eks-services.kubecfg
    }
  }
}
