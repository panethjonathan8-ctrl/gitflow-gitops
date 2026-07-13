include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "eso" {
  path = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/eso.hcl"
}
