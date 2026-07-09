# Account-wide constants — the single source of truth for values that used
# to be hardcoded separately in every environment's backend/provider block
# (terraform/environments/dev/main.tf and the old staging/main.tf).
#
# This plays the same role terraform.tfvars used to play for these specific
# values: it is read locally, never committed with secrets, but unlike
# terraform.tfvars these particular values (account ID, region, GitHub
# username) are not secret — they are safe to commit because Terragrunt's
# whole point is to have ONE place for them instead of copy-pasted per module.
locals {
  account_id      = "153772056450"
  aws_region      = "eu-west-1"
  project         = "gitflow-analyzer"
  github_username = "panethjonathan8-ctrl"
}
