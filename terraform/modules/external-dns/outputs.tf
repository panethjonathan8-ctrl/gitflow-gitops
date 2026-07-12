output "role_arn" {
  description = "ARN of the IAM role external-dns assumes via IRSA"
  value       = aws_iam_role.external_dns.arn
}
