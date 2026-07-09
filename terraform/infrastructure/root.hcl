# The top of the include tree — every unit under live/ includes this file.
# It does two things so we never write them by hand in 13 different places:
#
#   1. Generates the AWS provider block into every module's working directory.
#   2. Generates the S3 backend block, with the state key derived from the
#      module's path — so live/cluster/vpc gets its own state file automatically,
#      completely separate from live/cluster/eks, live/cluster/rds, etc.
#
# Same S3 bucket the project already uses (created in terraform/bootstrap) —
# Terragrunt just changes how state is organized inside it, not where it lives.

locals {
  account    = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  account_id = local.account.locals.account_id
  aws_region = local.account.locals.aws_region
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  region = "${local.aws_region}"
}
EOF
}

# Terraform doesn't allow two `required_providers` blocks in the same module.
# 3 modules (frontend-cdn, argocd-cdn, monitoring) already declare their own
# for the us_east_1 alias, so the version pin can't be generated centrally
# here — it's declared per-module instead (see modules/*/versions.tf, or the
# existing required_providers block in the 3 modules above).

remote_state {
  backend = "s3"
  config = {
    bucket       = "gitflow-analyzer-tfstate-${local.account_id}"
    key          = "${path_relative_to_include()}/terraform.tfstate"
    region       = local.aws_region
    encrypt      = true
    use_lockfile = true
  }
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}
