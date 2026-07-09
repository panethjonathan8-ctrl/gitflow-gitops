# Base config for the "dev" IRSA role. The staging/production variants
# (live/cluster/irsa-staging, live/cluster/irsa-production) include this
# file and override the `env`/`namespace` inputs — same merge pattern as
# secrets.hcl.
locals {
  account = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  env     = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/../modules/irsa"
}

dependency "eks" {
  config_path = "${get_terragrunt_dir()}/../eks"
  mock_outputs = {
    oidc_provider_arn       = "arn:aws:iam::000000000000:oidc-provider/mock"
    cluster_oidc_issuer_url = "https://mock"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

inputs = {
  project           = local.account.locals.project
  env               = local.env.locals.env_name
  oidc_provider_arn = dependency.eks.outputs.oidc_provider_arn
  oidc_issuer_url   = dependency.eks.outputs.cluster_oidc_issuer_url
  namespace         = "gitflow-analyzer-${local.env.locals.env_name}"
}
