include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "frontend_cdn" {
  path = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/frontend-cdn.hcl"
}
