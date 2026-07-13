include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "addons" {
  path = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/addons.hcl"
}
