terraform {
  required_version = ">= 1.10.5"

  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = "~> 5.0"
      configuration_aliases = [aws.us_east_1]
      # ACM certificates for CloudFront must be created in us-east-1 regardless
      # of where the rest of the infrastructure lives. The us_east_1 alias is
      # passed in from the calling environment.
    }
  }
}
