locals {
  account = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  env     = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/../modules/alb-lookup"
}

# Ordering only — this module doesn't need their outputs, just needs the ALB
# to already exist by the time it runs. The ALB is provisioned by
# aws-load-balancer-controller (in ../addons) in response to the shared
# Ingress object created by ../cluster-ingress.
dependencies {
  paths = ["../addons", "../cluster-ingress"]
}

inputs = {
  project = local.account.locals.project
  env     = local.env.locals.env_name
}
