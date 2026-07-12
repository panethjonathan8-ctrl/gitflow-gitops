include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "cluster_ingress" {
  path = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/cluster-ingress.hcl"
}
