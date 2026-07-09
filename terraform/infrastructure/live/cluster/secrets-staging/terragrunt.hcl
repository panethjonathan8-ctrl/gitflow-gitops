include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "secrets" {
  path = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/secrets.hcl"
}

# Overrides the "dev" env from _envcommon/secrets.hcl — creates
# gitflow-analyzer/staging/github-token instead.
inputs = {
  env = "staging"
}
