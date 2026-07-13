locals {
  account = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  env     = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/../modules/cluster-ingress"
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

dependency "dns" {
  config_path                             = "${get_terragrunt_dir()}/../dns"
  mock_outputs                            = { zone_id = "Z0000000000000000MOCK" }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

dependency "addons" {
  config_path = "${get_terragrunt_dir()}/../addons"
  mock_outputs = {
    ingress_nginx_namespace    = "ingress-nginx"
    ingress_nginx_service_name = "ingress-nginx-controller"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
  # Ordering dependency: the aws-lb-controller in the addons unit must be
  # running before this module's Ingress can actually provision an ALB.
}

# Creates a Kubernetes Ingress resource directly — needs the kubernetes
# provider generated here, same reasoning as _envcommon/argocd.hcl.
generate "k8s_providers" {
  path      = "k8s_providers.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
data "aws_eks_cluster_auth" "main" {
  name = "${dependency.eks.outputs.cluster_name}"
}

provider "kubernetes" {
  host                   = "${dependency.eks.outputs.cluster_endpoint}"
  cluster_ca_certificate = base64decode("${dependency.eks.outputs.cluster_ca_certificate}")
  token                  = data.aws_eks_cluster_auth.main.token
}
EOF
}

inputs = {
  project            = local.account.locals.project
  env                = local.env.locals.env_name
  argocd_hostname    = "argocd.gitflow.space"
  grafana_hostname   = "grafana.gitflow.space"
  route53_zone_id    = dependency.dns.outputs.zone_id
  nginx_namespace    = dependency.addons.outputs.ingress_nginx_namespace
  nginx_service_name = dependency.addons.outputs.ingress_nginx_service_name
}
