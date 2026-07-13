locals {
  account = read_terragrunt_config(find_in_parent_folders("account.hcl"))
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/../modules/secrets"
}

inputs = {
  project = local.account.locals.project
  env     = "dev"

  secret_names = [
    "github-token",
    "argocd-github-oauth-client-secret",
    "grafana-github-oauth-client-secret",
    "grafana-admin-password",
  ]
  # ArgoCD and Grafana are single cluster-wide instances (not per dev/staging/
  # production namespace like the app), so their secrets live in this base
  # "dev" secrets unit rather than being duplicated into secrets-staging/
  # secrets-production. External Secrets Operator (modules/addons) syncs these
  # containers into Kubernetes Secrets — see modules/argocd and
  # modules/monitoring. Values are still set manually via CLI after apply,
  # same as github-token; they never touch Terraform state or git.
}
