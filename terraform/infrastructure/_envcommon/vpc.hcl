locals {
  account  = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  env      = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  project  = local.account.locals.project
  env_name = local.env.locals.env_name
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/../modules/vpc"
}

inputs = {
  project  = local.project
  env      = local.env_name
  vpc_cidr = local.env.locals.vpc_cidr
  # public_subnet_cidrs / private_subnet_cidrs left at module defaults —
  # matches the original dev/main.tf, which also left these unset.
}
