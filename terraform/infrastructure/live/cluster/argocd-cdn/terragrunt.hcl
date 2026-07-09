include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "argocd_cdn" {
  path = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/argocd-cdn.hcl"
}
