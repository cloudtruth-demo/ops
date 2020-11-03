output "kubecfg" {
  description = <<-EOF
   Apply this config to allow the kubecfg client to talk to the cluster.
   Can be applied by:
    * Directly editing ~/.kube/config
    * Running 'aws eks update-kubeconfig'
    * Saving to a yaml file and running 'kubectl apply -f saved.yaml'
EOF

  value = data.template_file.kubeconfig.rendered
}

output "cluster_name" {
  description = "The cluster name"
  value       = aws_eks_cluster.main.name
}

output "cluster_security_group_id" {
  description = "The security group used to grant the cluster network permissions"
  value       = aws_security_group.cluster.id
}

output "cluster_role" {
  description = "The cluster's role"
  value       = aws_iam_role.cluster.name
}

output "pod_execution_role" {
  description = "The role used to grant the pod's execution framework IAM permissions"
  value       = aws_iam_role.pod-execution.name
}

output "cluster_endpoint" {
  description = "The cluster endpoint"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_cert" {
  description = "The cluster cert (base64 decoded)"
  value       = base64decode(aws_eks_cluster.main.certificate_authority[0].data)
}

output "cluster_token" {
  description = "A temporary auth token used to access the cluster"
  value       = data.aws_eks_cluster_auth.main.token
}

output "oidc_issuer_url" {
  description = "The OIDC issuer URL"
  value       = aws_eks_cluster.main.identity[0].oidc[0].issuer
}
