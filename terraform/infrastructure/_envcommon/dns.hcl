locals {
  account = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  env     = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/../modules/dns"
}

inputs = {
  project     = local.account.locals.project
  env         = local.env.locals.env_name
  domain_name = "gitflow.space"
}
