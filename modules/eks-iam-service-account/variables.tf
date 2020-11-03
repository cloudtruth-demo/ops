variable "name" {
  description = "The service account name"
}

variable "namespace" {
  description = "The kubernetes namespace for the service account"
  default = null
}

variable "cluster_name" {
  description = "The kubernetes cluster name"
}

variable "automount_token" {
  description = "Automount the service account token"
  default = false
}

