variable "project" {
  description = "Project name — used in resource names and tags"
  type        = string
}

variable "env" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "alb_dns_name" {
  description = "DNS name of the ALB that fronts result-api — CloudFront proxies /api/* here"
  type        = string
}

variable "domain_name" {
  description = "Apex domain for the CloudFront distribution (e.g. gitflow.space) — ACM certificate covers this and www.domain"
  type        = string
}

variable "route53_zone_id" {
  description = "Route53 hosted zone ID for domain_name — used to create the alias records that point the domain at CloudFront"
  type        = string
}
