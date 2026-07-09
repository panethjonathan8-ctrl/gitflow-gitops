include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "alb_lookup" {
  path = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/alb-lookup.hcl"
}
