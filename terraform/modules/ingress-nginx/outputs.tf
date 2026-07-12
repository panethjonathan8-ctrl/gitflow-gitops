output "namespace" {
  description = "Kubernetes namespace running the nginx ingress controller"
  value       = kubernetes_namespace.ingress_nginx.metadata[0].name
}

output "service_name" {
  description = "Kubernetes Service name for the nginx ingress controller — used as the backend for the shared ALB Ingress"
  value       = "ingress-nginx-controller"
  # Fixed by the Helm chart's naming convention: "<release-name>-controller".
}
