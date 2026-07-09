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

dependency "alb_lookup" {
  config_path                             = "${get_terragrunt_dir()}/../alb-lookup"
  mock_outputs                            = { alb_dns_name = "mock.elb.amazonaws.com" }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

# CloudFront cert (grafana.gitflow.space) needs us-east-1, and the module
# also installs Helm charts (kube-prometheus-stack, Loki, Tempo, Alloy) —
# needs both the us_east_1 alias and the k8s providers.
generate "providers_extra" {
  path      = "providers_extra.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

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
  project                    = local.account.locals.project
  env                        = local.env.locals.env_name
  grafana_admin_password     = local.secrets.locals.grafana_admin_password
  github_oauth_client_id     = local.secrets.locals.github_oauth_client_id
  github_oauth_client_secret = local.secrets.locals.github_oauth_client_secret
  github_oauth_allowed_user  = local.secrets.locals.github_oauth_allowed_user
  alb_dns_name               = dependency.alb_lookup.outputs.alb_dns_name
  # grafana_hostname uses the module default (grafana.gitflow.space)
}
