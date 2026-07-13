variable "project" {
  description = "Project name — used for naming IAM resources"
  type        = string
}

variable "env" {
  description = "Environment name — used for naming IAM resources"
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the EKS OIDC provider — Federated principal in the eso trust policy"
  type        = string
}

variable "oidc_issuer_url" {
  description = "OIDC issuer URL — used to scope the trust policy to eso's own service account"
  type        = string
}

variable "aws_region" {
  description = "AWS region — the ClusterSecretStore reads Secrets Manager secrets from this region"
  type        = string
}

variable "chart_version" {
  description = "Version of the external-secrets Helm chart — pin to avoid unexpected upgrades"
  type        = string
  default     = "2.7.0"
  # Check for newer versions at: https://artifacthub.io/packages/helm/external-secrets/external-secrets
}
