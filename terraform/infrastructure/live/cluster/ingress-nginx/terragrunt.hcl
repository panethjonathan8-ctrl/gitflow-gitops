include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "ingress_nginx" {
  path = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/ingress-nginx.hcl"
}
