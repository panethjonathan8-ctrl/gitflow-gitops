locals {
  account = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  env     = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  secrets = read_terragrunt_config(find_in_parent_folders("secrets.hcl"))
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/../modules/monitoring"
}

dependency "eks" {
  config_path = "${get_terragrunt_dir()}/../eks"
  mock_outputs = {
    cluster_name           = "mock-cluster"
    cluster_endpoint       = "https://mock"
    cluster_ca_certificate = "bW9jaw=="
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

dependency "addons" {
  config_path                             = "${get_terragrunt_dir()}/../addons"
  mock_outputs                            = { cluster_secret_store_name = "aws-secrets-manager" }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
  # Ordering dependency: the ExternalSecrets this module creates need the
  # addons unit's ClusterSecretStore and CRDs to already exist in the cluster.
}

# The module installs Helm charts (kube-prometheus-stack, Loki, Tempo,
# Alloy) — needs the k8s providers generated here, same reasoning as
# _envcommon/argocd.hcl. No us-east-1 alias needed anymore now that Grafana
# is reached via the shared ALB (modules/cluster-ingress) instead of its own
# CloudFront distribution.
generate "k8s_providers" {
  path      = "k8s_providers.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
data "aws_eks_cluster_auth" "main" {
  name = "${dependency.eks.outputs.cluster_name}"
}

provider "helm" {
  kubernetes {
    host                   = "${dependency.eks.outputs.cluster_endpoint}"
    cluster_ca_certificate = base64decode("${dependency.eks.outputs.cluster_ca_certificate}")
    token                  = data.aws_eks_cluster_auth.main.token
  }
}

provider "kubernetes" {
  host                   = "${dependency.eks.outputs.cluster_endpoint}"
  cluster_ca_certificate = base64decode("${dependency.eks.outputs.cluster_ca_certificate}")
  token                  = data.aws_eks_cluster_auth.main.token
}
EOF
}

inputs = {
  project                   = local.account.locals.project
  env                       = local.env.locals.env_name
  cluster_secret_store      = dependency.addons.outputs.cluster_secret_store_name
  github_oauth_client_id    = local.secrets.locals.github_oauth_client_id
  github_oauth_allowed_user = local.secrets.locals.github_oauth_allowed_user
  # grafana_hostname uses the module default (grafana.gitflow.space)
  # grafana_admin_password and github_oauth_client_secret no longer passed as
  # Terraform inputs — modules/monitoring now syncs both from Secrets Manager
  # via ExternalSecrets (see modules/addons). Set the real values once with:
  #   aws secretsmanager put-secret-value \
  #     --secret-id gitflow-analyzer/dev/grafana-admin-password --secret-string '<value>'
  #   aws secretsmanager put-secret-value \
  #     --secret-id gitflow-analyzer/dev/grafana-github-oauth-client-secret --secret-string '<value>'
}
