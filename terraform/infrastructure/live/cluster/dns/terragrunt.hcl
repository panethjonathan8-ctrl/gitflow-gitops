include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "dns" {
  path = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/dns.hcl"
}
