locals {
  account = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  env     = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/../modules/argocd-cdn"
}

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

inputs = {
  project      = local.account.locals.project
  env          = local.env.locals.env_name
  alb_dns_name = dependency.alb_lookup.outputs.alb_dns_name
  # argocd_hostname uses the module default (argocd.gitflow.space)
}
