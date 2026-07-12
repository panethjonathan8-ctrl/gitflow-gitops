variable "project" {
  description = "Project name — used for tagging"
  type        = string
}

variable "env" {
  description = "Environment name — used for tagging"
  type        = string
}

variable "argocd_hostname" {
  description = "Public hostname for ArgoCD"
  type        = string
}

variable "grafana_hostname" {
  description = "Public hostname for Grafana"
  type        = string
}

variable "route53_zone_id" {
  description = "Route53 hosted zone ID used to DNS-validate the ACM certificate"
  type        = string
}

variable "nginx_namespace" {
  description = "Namespace the nginx ingress controller runs in — the shared ALB Ingress lives here too, so it can reference the controller's Service directly"
  type        = string
}

variable "nginx_service_name" {
  description = "Kubernetes Service name for the nginx ingress controller — backend target for the shared ALB"
  type        = string
}
