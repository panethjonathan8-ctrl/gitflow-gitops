variable "project" {
  description = "Project name — used for tagging the namespace"
  type        = string
}

variable "env" {
  description = "Environment name — used for tagging the namespace"
  type        = string
}

variable "chart_version" {
  description = "Version of the ingress-nginx Helm chart — pin to avoid unexpected upgrades"
  type        = string
  default     = "4.11.3"
}
