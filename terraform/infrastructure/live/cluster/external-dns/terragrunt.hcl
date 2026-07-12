include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "external_dns" {
  path = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/external-dns.hcl"
}
