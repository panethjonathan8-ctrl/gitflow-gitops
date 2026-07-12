variable "project" {
  description = "Project name — used for tagging"
  type        = string
}

variable "env" {
  description = "Environment name — used for tagging"
  type        = string
}

variable "domain_name" {
  description = "Domain name to create a public Route53 hosted zone for"
  type        = string
}
