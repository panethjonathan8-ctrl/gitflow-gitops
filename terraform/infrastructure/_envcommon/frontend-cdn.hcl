locals {
  account = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  env     = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/../modules/frontend-cdn"
}

# ACM certificates for CloudFront must be issued in us-east-1 — AWS hard
# requirement, regardless of which region the rest of the infra runs in.
# modules/frontend-cdn declares `configuration_aliases = [aws.us_east_1]`
# and expects this alias to exist in the same root it's applied in.
generate "provider_us_east_1" {
  path      = "provider_us_east_1.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}
EOF
}

dependency "alb_lookup" {
  config_path                             = "${get_terragrunt_dir()}/../alb-lookup"
  mock_outputs                            = { alb_dns_name = "mock.elb.amazonaws.com" }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

dependency "dns" {
  config_path                             = "${get_terragrunt_dir()}/../dns"
  mock_outputs                            = { zone_id = "Z0000000000000000MOCK" }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

inputs = {
  project         = local.account.locals.project
  env             = local.env.locals.env_name
  alb_dns_name    = dependency.alb_lookup.outputs.alb_dns_name
  domain_name     = "gitflow.space"
  route53_zone_id = dependency.dns.outputs.zone_id
}
