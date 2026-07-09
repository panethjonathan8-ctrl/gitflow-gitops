locals {
  account = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  env     = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/../modules/alb-lookup"
}

# Ordering only — this module doesn't need their outputs, just needs the ALB
# to already exist by the time it runs. Matches the original
# depends_on = [module.aws_lb_controller, module.argocd] in dev/main.tf,
# since the ALB is created when ArgoCD syncs the Ingress, not by Terraform.
dependencies {
  paths = ["../aws-lb-controller", "../argocd"]
}

inputs = {
  project = local.account.locals.project
  env     = local.env.locals.env_name
}
