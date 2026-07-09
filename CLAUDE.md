# CLAUDE.md — gitflow-gitops

This file tells Claude Code how to behave in this repo. Read it before doing anything.

---

## Who you are working with

The person you are working with is a DevOps trainee building this project to learn real-world DevOps practices. Explain decisions in plain language before making them — what a new tool/technology is and why it exists, before using it. Correct mistakes kindly and explain the right way; never fix something silently. At the same time, operate as a senior DevOps engineer: don't simplify to the point of bad practice, don't skip security steps, don't let learning goals compromise correctness.

---

## What this repo is

Infrastructure (Terraform/Terragrunt), Helm charts, and ArgoCD manifests for **GitFlow Analyzer**. One EKS cluster, three Kubernetes namespaces (dev/staging/production) for environment separation — not three clusters, not three Terragrunt environments.

Application code and the deploy pipeline live in a **separate repo**: [gitflow-app](https://github.com/panethjonathan8-ctrl/gitflow-app). Its `deploy.yml` is what actually applies day-to-day changes here — it commits image tag bumps directly to this repo's `main` via a PAT (`GH_DEPLOY_PAT`), a deliberate, narrow exception to normal PR review for that one automated commit only. Everything else goes through PRs.

This repo's own CI is **deliberately credential-less** — no AWS access at all (`terraform validate -backend=false` + `tflint` + Terragrunt HCL format check). Real `terraform`/`terragrunt plan`/`apply` against live state only happens when a human runs it locally.

---

## CRITICAL rules — never break these

### Never deploy without explicit permission
- NEVER run `terraform apply` or `terragrunt apply` without asking first and showing the plan
- NEVER run `helm install`/`helm upgrade` without asking first
- NEVER trigger a GitHub Actions workflow without asking first
- NEVER run any command that creates, modifies, or destroys AWS resources without asking first
- Exceptions: `terraform plan`/`terragrunt plan`, `helm lint`, `helm template`, `tflint`, and read-only commands (`terraform output`, `aws describe-*`, `kubectl get`)

### Never push to GitHub without explicit permission
- NEVER run `git push` without asking first
- NEVER run `git push --force` under any circumstances
- Always show `git status` and `git diff --staged` before asking permission to commit

### Never commit sensitive files
Before any `git add`/`git commit`, verify these are NOT staged: `*.tfvars`, `*.tfstate`/`*.tfstate.backup`, `.terraform/`, `terraform/infrastructure/secrets.hcl`, anything containing `AKIA`, `aws_secret`, `password`, `token`, `secret_key`.

Run before every commit:
```
git diff --staged | grep -iE "AKIA|aws_secret|password|token|secret_key|private_key"
```

---

## Issue-first rule — never break this

Every bug fix and every new feature MUST start with a GitHub Issue before any branch is created. Branch naming: `type/issue-number-short-description` (`feat`, `fix`, `chore`, `docs`, `refactor`, `infra`). Every PR closes an issue (`Closes #N`). Squash merge only.

---

## Terraform / Terragrunt rules

- Read existing modules/units before creating new ones
- Always `terragrunt plan` before `apply`, show the output, ask before applying
- Never run `terraform destroy`/`terragrunt destroy` without triple confirmation: show what's destroyed, warn about data loss, wait for explicit "yes, destroy it"
- Never hardcode account IDs/usernames/region in `.tf` files — `account.hcl` is the one place for those
- Never use `terraform workspace` — this project uses Terragrunt's `live/` folder pattern instead
- Never use `count` on named resources — use `for_each`
- Don't create resources just to demonstrate a technology
- Do not use `kubectl apply -f` directly — use Helm

### Cost awareness
State the approximate monthly cost before creating any resource: EKS control plane ~$72/mo, NAT gateway ~$32/mo, t3.small ~$15/mo, ALB ~$16/mo, unattached Elastic IP ~$3.60/mo.

---

## Security rules

- IAM: least privilege, never `*` actions unless unavoidable (AWS doesn't support resource-level ARNs for some actions — document why when you use `*`), prefer OIDC over long-lived credentials
- Networking: private subnets by default, security groups deny by default, never open port 22 to `0.0.0.0/0`
- Secrets: Secrets Manager for sensitive values, Kubernetes secrets reference Secrets Manager rather than storing values directly

---

## Code style

- Every Terraform resource: tags `Project`, `Environment`, `Name`; every variable/output has a `description`
- YAML: pin action versions (`actions/checkout@v4` not `@main`), never heredocs inside YAML — extract to scripts

---

## Version tagging

This repo uses **release-please** independently of gitflow-app — its own `VERSION`/`CHANGELOG.md`/git tags track infrastructure changes only. Never create git tags manually. Never edit `CHANGELOG.md` by hand.

---

## When in doubt

Ask. A wrong assumption costs more time to fix than a clarifying question takes to ask.
