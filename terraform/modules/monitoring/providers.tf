terraform {
  required_version = ">= 1.10.5"

  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = "~> 5.0"
      configuration_aliases = [aws.us_east_1]
      # CloudFront certificates must live in us-east-1 — AWS hard requirement.
      # The us_east_1 alias is passed in from the calling environment.
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}
