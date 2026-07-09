locals {
  account = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  env     = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/../modules/aws-lb-controller"
}

dependency "vpc" {
  config_path                             = "${get_terragrunt_dir()}/../vpc"
  mock_outputs                            = { vpc_id = "vpc-mock" }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

dependency "eks" {
  config_path = "${get_terragrunt_dir()}/../eks"
  mock_outputs = {
    cluster_name            = "mock-cluster"
    cluster_endpoint        = "https://mock"
    cluster_ca_certificate  = "bW9jaw=="
    oidc_provider_arn       = "arn:aws:iam::000000000000:oidc-provider/mock"
    cluster_oidc_issuer_url = "https://mock"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

# This module installs a Helm chart onto the cluster — needs helm/kubernetes
# providers generated here, same reasoning as _envcommon/argocd.hcl.
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
  project           = local.account.locals.project
  env               = local.env.locals.env_name
  cluster_name      = dependency.eks.outputs.cluster_name
  vpc_id            = dependency.vpc.outputs.vpc_id
  aws_region        = local.account.locals.aws_region
  oidc_provider_arn = dependency.eks.outputs.oidc_provider_arn
  oidc_issuer_url   = dependency.eks.outputs.cluster_oidc_issuer_url
}
