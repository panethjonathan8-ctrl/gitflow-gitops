terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
      # Used to fetch the EKS OIDC issuer's TLS certificate thumbprint for
      # the aws_iam_openid_connect_provider trust setup (IRSA).
    }
  }
}
