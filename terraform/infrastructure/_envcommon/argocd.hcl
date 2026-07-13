locals {
  account = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  env     = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  secrets = read_terragrunt_config(find_in_parent_folders("secrets.hcl"))
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/../modules/argocd"
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
  # Ordering dependency: the ExternalSecret this module creates needs the
  # addons unit's ClusterSecretStore and CRDs to already exist in the cluster.
}

# The argocd module creates helm_release/kubernetes_* resources, which need
# helm and kubernetes providers. Under plain Terraform these were defined
# once in dev/main.tf's root and inherited by every module automatically.
# Under Terragrunt, each unit is its own root, so any unit that touches the
# cluster must generate these providers itself, pointed at the EKS unit's
# outputs via the dependency block above.
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
  project              = local.account.locals.project
  env                  = local.env.locals.env_name
  cluster_name         = dependency.eks.outputs.cluster_name
  aws_region           = local.account.locals.aws_region
  cluster_secret_store = dependency.addons.outputs.cluster_secret_store_name

  argocd_github_oauth_client_id = local.secrets.locals.argocd_github_oauth_client_id
  argocd_github_allowed_user    = local.secrets.locals.argocd_github_allowed_user
  # argocd_github_oauth_client_secret no longer passed as a Terraform input —
  # modules/argocd now syncs it from Secrets Manager via an ExternalSecret
  # (see modules/addons). Set the real value once with:
  #   aws secretsmanager put-secret-value \
  #     --secret-id gitflow-analyzer/dev/argocd-github-oauth-client-secret \
  #     --secret-string '<value>'
}
