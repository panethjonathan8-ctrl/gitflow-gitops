include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "iam" {
  path = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/iam.hcl"
}
