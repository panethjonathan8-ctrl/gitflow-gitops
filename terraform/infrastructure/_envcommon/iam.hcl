locals {
  account = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  env     = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/../modules/iam"
}

inputs = {
  project         = local.account.locals.project
  env             = local.env.locals.env_name
  github_username = local.account.locals.github_username
  # Only gitflow-app gets a trusted role — it's the only repo whose CI
  # touches AWS (build+push images, update kubeconfig, deploy). gitflow-gitops
  # CI is deliberately credential-less; a human runs terragrunt apply locally.
  github_repo    = "gitflow-app"
  aws_account_id = local.account.locals.account_id
}
