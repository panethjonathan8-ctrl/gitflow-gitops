locals {
  account = read_terragrunt_config(find_in_parent_folders("account.hcl"))
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/../modules/secrets"
}

inputs = {
  project = local.account.locals.project
  env     = "dev"
}
