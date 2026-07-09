# Two-layer design that survives nightly EKS teardown. Originally inline in
# terraform/environments/dev/main.tf; extracted into its own module because
# under Terragrunt each unit (frontend-cdn, argocd-cdn, monitoring) is a
# separate Terraform state, so the lookup can no longer be shared as one
# root-level data source the way it was in the single monorepo root module.
#
#   Layer 1 — data.aws_lb (runs only when the cluster + ALB are up)
#     Looks up the ALB by the tags the AWS Load Balancer Controller puts on
#     it, then writes the DNS name into SSM Parameter Store.
#
#   Layer 2 — data.aws_ssm_parameter (always works)
#     Reads the last-known ALB hostname from SSM. SSM retains the value even
#     after the cluster is destroyed, so downstream units (frontend-cdn,
#     argocd-cdn, monitoring) can read this module's output and plan cleanly
#     overnight without a running cluster.

data "aws_lb" "app" {
  tags = {
    "elbv2.k8s.aws/cluster" = "${var.project}-${var.env}"
    "ingress.k8s.aws/stack" = "gitflow-analyzer"
  }
}

resource "aws_ssm_parameter" "alb_dns_name" {
  name  = "/${var.project}/${var.env}/alb-dns-name"
  type  = "String"
  value = data.aws_lb.app.dns_name

  tags = {
    Project     = var.project
    Environment = var.env
  }
}

data "aws_ssm_parameter" "alb_dns_name" {
  name       = "/${var.project}/${var.env}/alb-dns-name"
  depends_on = [aws_ssm_parameter.alb_dns_name]
}
