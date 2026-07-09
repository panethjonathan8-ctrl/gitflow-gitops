locals {
  account = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  env     = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/../modules/eks"
}

dependency "vpc" {
  config_path = "${get_terragrunt_dir()}/../vpc"
  mock_outputs = {
    vpc_id            = "vpc-mock"
    public_subnet_ids = ["subnet-mock1", "subnet-mock2"]
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

dependency "iam" {
  config_path = "${get_terragrunt_dir()}/../iam"
  mock_outputs = {
    github_actions_role_arn = "arn:aws:iam::000000000000:role/mock"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

# RDS's security group ID is stable even when EKS is torn down nightly, so
# EKS can safely depend on it. This is the reverse of the original comment's
# reasoning ("lives here so it is destroyed/recreated WITH the EKS cluster,
# the RDS instance and its security group are unaffected") — same outcome,
# just expressed as "eks depends on rds's (stable) output" instead of "an
# inline resource in the shared root module".
dependency "rds" {
  config_path = "${get_terragrunt_dir()}/../rds"
  mock_outputs = {
    rds_security_group_id = "sg-mock"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

# Allows pods on EKS nodes to reach PostgreSQL on port 5432. Originally a
# standalone aws_security_group_rule in dev/main.tf, kept as a generated
# resource here (not inside modules/eks or modules/rds) for the same reason
# it was standalone before: it is destroyed and recreated with the EKS
# cluster on the nightly teardown, without touching the RDS module itself.
generate "eks_to_rds_rule" {
  path      = "eks_to_rds_rule.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
resource "aws_security_group_rule" "eks_to_rds" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = "${dependency.rds.outputs.rds_security_group_id}"
  # References the eks module's own aws_eks_cluster.main resource directly —
  # this generated file lands in the same working directory as the eks
  # module's source (Terragrunt runs the module as the root, not via a
  # nested `module` block), so it's a sibling resource reference, not a
  # cross-module one.
  source_security_group_id = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
  description               = "PostgreSQL from EKS nodes"
}
EOF
}

inputs = {
  project        = local.account.locals.project
  env            = local.env.locals.env_name
  vpc_id         = dependency.vpc.outputs.vpc_id
  subnet_ids     = dependency.vpc.outputs.public_subnet_ids
  instance_types = ["t3a.large"]
  # t3a.large = 2 vCPU, 8 GB RAM — sized for Prometheus + Grafana headroom
  # alongside ArgoCD and the app pods (see original dev/main.tf comment).
  desired_size            = 2
  max_size                = 2
  github_actions_role_arn = dependency.iam.outputs.github_actions_role_arn
}
