variable "atmos_env" {
  description = "The atmos environment"
}

variable "global_name_prefix" {
  description = <<-EOF
    The global name prefix for disambiguating resource names that have a global
    scope (e.g. s3 bucket names)
EOF


  default = ""
}

variable "local_name_prefix" {
  description = <<-EOF
    The local name prefix for disambiguating resource names that have a local scope
    (e.g. when running multiple environments in the same account)
EOF


  default = ""
}

variable "region" {
  description = "The aws region"
}

variable "name" {
  description = "The component name"
}

variable "vpc_id" {
  description = "VPC for instances"
}

variable "namespaces" {
  description = "The cluster namespace"
  type = list(string)
  default     = ["default"]
}

variable "cluster_subnet_ids" {
  description = "Subnets used by the EKS cluster"
  type        = list(string)
}

variable "profile_subnet_ids" {
  description = "Subnets used for the fargate profile"
  type        = list(string)
}

variable "cluster_security_groups" {
  description = "The security groups to associate the cluster with"
  type        = list(string)
  default     = []
}

variable "kubernetes_version" {
  description = "The kubernetes version for the cluster"
  type = string
  default = null
}