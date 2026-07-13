variable "project" {
  description = "Project name — used for naming IAM resources"
  type        = string
}

variable "env" {
  description = "Environment name — used for naming IAM resources"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name — passed to the LB controller and used by the ClusterSecretStore local-exec to update kubeconfig"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID — the LB controller needs this to create ALBs in the right VPC"
  type        = string
}

variable "aws_region" {
  description = "AWS region — used for regional API calls and the ClusterSecretStore's Secrets Manager region"
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the EKS OIDC provider — Federated principal in each addon's trust policy"
  type        = string
}

variable "oidc_issuer_url" {
  description = "OIDC issuer URL — used to scope each addon's trust policy to its own service account"
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

variable "lb_controller_chart_version" {
  description = "Version of the aws-load-balancer-controller Helm chart"
  type        = string
  default     = "1.8.3"
  # Chart 1.8.3 = controller image v2.8.3
  # Check releases at: https://github.com/kubernetes-sigs/aws-load-balancer-controller/releases
}

variable "ingress_nginx_chart_version" {
  description = "Version of the ingress-nginx Helm chart"
  type        = string
  default     = "4.11.3"
}

variable "external_dns_chart_version" {
  description = "Version of the external-dns Helm chart"
  type        = string
  default     = "1.15.0"
}

variable "eso_chart_version" {
  description = "Version of the external-secrets Helm chart"
  type        = string
  default     = "2.7.0"
  # Check for newer versions at: https://artifacthub.io/packages/helm/external-secrets/external-secrets
}
