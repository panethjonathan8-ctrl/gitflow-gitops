include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "irsa" {
  path = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/irsa.hcl"
}

inputs = {
  env       = "staging"
  namespace = "gitflow-analyzer-staging"
}
