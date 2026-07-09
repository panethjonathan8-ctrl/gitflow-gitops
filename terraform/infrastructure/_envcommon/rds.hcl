locals {
  account = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  env     = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/../modules/rds"
}

dependency "vpc" {
  config_path = "${get_terragrunt_dir()}/../vpc"
  mock_outputs = {
    vpc_id             = "vpc-mock"
    private_subnet_ids = ["subnet-mock1", "subnet-mock2"]
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

# Deliberately no dependency on eks — this unit must plan/apply cleanly
# whether or not the cluster is up, same as the original design (the
# eks-to-rds ingress rule lives in the eks unit instead, see _envcommon/eks.hcl).
inputs = {
  project            = local.account.locals.project
  env                = local.env.locals.env_name
  vpc_id             = dependency.vpc.outputs.vpc_id
  private_subnet_ids = dependency.vpc.outputs.private_subnet_ids
}
