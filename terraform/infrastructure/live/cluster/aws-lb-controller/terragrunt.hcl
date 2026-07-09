include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "aws_lb_controller" {
  path = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/aws-lb-controller.hcl"
}
