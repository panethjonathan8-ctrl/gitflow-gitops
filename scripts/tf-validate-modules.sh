#!/bin/bash
# Runs `terraform validate` against every module in terraform/modules/,
# in isolation, with no AWS credentials (-backend=false).
#
# Modules that declare `configuration_aliases = [aws.us_east_1]` (for
# CloudFront ACM certs, which must be created in us-east-1 regardless of the
# main region) can't be validated standalone — the alias is only ever
# supplied by the Terragrunt caller. This script injects a throwaway
# provider block supplying that alias just for validation, then removes it.
set -e

ALIASED_MODULES=("frontend-cdn" "argocd-cdn" "monitoring")

for dir in terraform/modules/*/; do
  module=$(basename "$dir")
  echo "=== Validating $module ==="

  needs_alias=false
  for m in "${ALIASED_MODULES[@]}"; do
    [ "$module" = "$m" ] && needs_alias=true
  done

  if [ "$needs_alias" = true ]; then
    cat > "$dir/validate_us_east_1_provider.tf" <<'EOF'
# Injected only for standalone `terraform validate` in CI — not part of the
# real module. Terragrunt supplies the real us_east_1 provider at apply time.
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}
EOF
  fi

  (cd "$dir" && terraform init -backend=false -input=false && terraform validate)

  if [ "$needs_alias" = true ]; then
    rm -f "$dir/validate_us_east_1_provider.tf"
  fi
done
