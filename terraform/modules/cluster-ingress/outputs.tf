output "certificate_arn" {
  description = "ARN of the shared ACM certificate covering ArgoCD and Grafana"
  value       = aws_acm_certificate_validation.cluster.certificate_arn
}
