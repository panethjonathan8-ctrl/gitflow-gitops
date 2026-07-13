output "role_arn" {
  description = "ARN of the IAM role eso assumes via IRSA"
  value       = aws_iam_role.eso.arn
}

output "cluster_secret_store_name" {
  description = "Name of the ClusterSecretStore — reference this in ExternalSecret.spec.secretStoreRef.name from any namespace"
  value       = local.cluster_secret_store_name
}
