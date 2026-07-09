locals {
  account = read_terragrunt_config(find_in_parent_folders("account.hcl"))
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/../modules/ecr"
}

inputs = {
  project = local.account.locals.project
  # frontend intentionally excluded — static files are served from S3/CloudFront.
  services = ["analyzer", "graph-builder", "result-api"]
}
