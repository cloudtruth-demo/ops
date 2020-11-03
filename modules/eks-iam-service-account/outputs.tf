output "name" {
  description = "The service account name"
  value       = var.name
}

output "role" {
  description = "The role used to grant the service account IAM permissions"
  value       = aws_iam_role.role.name
}
