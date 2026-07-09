include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "eks" {
  path = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/eks.hcl"
}
