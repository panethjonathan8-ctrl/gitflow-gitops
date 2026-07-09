# gitflow-gitops

Infrastructure (Terraform/Terragrunt), Helm charts, and ArgoCD manifests for GitFlow Analyzer.

## Layout

```
terraform/
  modules/           Reusable Terraform modules (vpc, eks, rds, argocd, ...)
  infrastructure/     Terragrunt: root.hcl, account.hcl, _envcommon/, live/cluster/
  bootstrap/          One-time bootstrap (S3 state bucket)
k8s/
  helm/gitflow-analyzer/   The app's Helm chart (values-dev/staging/production.yaml)
  helm/grafana-dashboards/ Grafana dashboard provisioning
  argocd/                  ArgoCD Application manifests — what ArgoCD watches
```

One EKS cluster (`terraform/infrastructure/live/cluster/`), three Kubernetes namespaces (dev/staging/production) for environment separation — not three clusters.

## Related repo

Application code and the deploy pipeline live in a separate repo: [gitflow-app](https://github.com/panethjonathan8-ctrl/gitflow-app). Its `deploy.yml` is what actually applies changes here — it bumps the image tag in `k8s/helm/gitflow-analyzer/values-*.yaml` and pushes directly to this repo's `main` (a deliberate, narrow exception to normal PR review, for that one automated commit only).

## CI/CD

This repo's own CI is deliberately credential-less — no AWS access at all:

- `terraform-plan.yml` — `terraform validate` (via `-backend=false`, no AWS needed) + `tflint` + Terragrunt HCL format check, on every PR touching `terraform/**`
- `helm-lint.yml` — `helm lint` + `helm template` on every PR touching `k8s/**`

Real `terraform plan`/`apply` against live state happens from a human running `terragrunt plan`/`apply` locally — see CLAUDE.md.

See CLAUDE.md for how this project expects infrastructure changes to be made (issue-first, always plan before apply, cost/security callouts).
