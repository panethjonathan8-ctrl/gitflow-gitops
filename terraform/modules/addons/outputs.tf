output "lb_controller_role_arn" {
  description = "ARN of the IAM role the LB controller assumes via IRSA"
  value       = aws_iam_role.lb_controller.arn
}

output "ingress_nginx_namespace" {
  description = "Kubernetes namespace running the nginx ingress controller"
  value       = kubernetes_namespace.ingress_nginx.metadata[0].name
}

output "ingress_nginx_service_name" {
  description = "Kubernetes Service name for the nginx ingress controller — used as the backend for the shared ALB Ingress"
  value       = "ingress-nginx-controller"
  # Fixed by the Helm chart's naming convention: "<release-name>-controller".
}

output "external_dns_role_arn" {
  description = "ARN of the IAM role external-dns assumes via IRSA"
  value       = aws_iam_role.external_dns.arn
}

output "eso_role_arn" {
  description = "ARN of the IAM role eso assumes via IRSA"
  value       = aws_iam_role.eso.arn
}

output "cluster_secret_store_name" {
  description = "Name of the ClusterSecretStore — reference this in ExternalSecret.spec.secretStoreRef.name from any namespace"
  value       = "aws-secrets-manager"
}
