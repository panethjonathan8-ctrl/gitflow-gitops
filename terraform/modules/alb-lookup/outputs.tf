output "alb_dns_name" {
  description = "Last-known ALB DNS name, read from SSM — resolves even when the cluster and ALB are torn down"
  value       = data.aws_ssm_parameter.alb_dns_name.value
  sensitive   = true
}
