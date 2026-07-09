include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "monitoring" {
  path = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/monitoring.hcl"
}
