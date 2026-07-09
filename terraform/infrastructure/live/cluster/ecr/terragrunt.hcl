include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "ecr" {
  path = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/ecr.hcl"
}
