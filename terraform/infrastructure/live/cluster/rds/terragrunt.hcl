include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "rds" {
  path = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/rds.hcl"
}
