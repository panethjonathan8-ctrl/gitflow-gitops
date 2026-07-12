variable "project" {
  description = "Project name — used for naming IAM resources"
  type        = string
}

variable "env" {
  description = "Environment name — used for naming IAM resources"
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the EKS OIDC provider — Federated principal in external-dns's trust policy"
  type        = string
}

variable "oidc_issuer_url" {
  description = "OIDC issuer URL — used to scope the trust policy to external-dns's own service account"
  type        = string
}

variable "route53_zone_id" {
  description = "Route53 hosted zone ID external-dns is allowed to write records into"
  type        = string
}

variable "domain_filter" {
  description = "Domain external-dns is allowed to manage records for"
  type        = string
}

variable "chart_version" {
  description = "Version of the external-dns Helm chart — pin to avoid unexpected upgrades"
  type        = string
  default     = "1.15.0"
}
