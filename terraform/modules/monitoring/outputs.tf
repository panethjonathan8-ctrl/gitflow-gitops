output "namespace" {
  description = "Kubernetes namespace where Prometheus and Grafana are installed"
  value       = kubernetes_namespace.monitoring.metadata[0].name
}

output "grafana_service_name" {
  description = "Kubernetes service name for Grafana — use with kubectl port-forward to access the UI"
  value       = "monitoring-grafana"
}

output "grafana_url" {
  description = "Public URL for Grafana"
  value       = "https://${var.grafana_hostname}"
}
