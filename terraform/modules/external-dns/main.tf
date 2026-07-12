locals {
  oidc_host            = replace(var.oidc_issuer_url, "https://", "")
  namespace            = "external-dns"
  service_account_name = "external-dns"
}

resource "kubernetes_namespace" "external_dns" {
  metadata {
    name = local.namespace
    labels = {
      Project                        = var.project
      Environment                    = var.env
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

# ── Trust policy ──────────────────────────────────────────────────────────────
# Same IRSA pattern as modules/irsa and modules/aws-lb-controller, scoped to
# external-dns's own service account instead.
data "aws_iam_policy_document" "trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:sub"
      values   = ["system:serviceaccount:${local.namespace}:${local.service_account_name}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "external_dns" {
  name               = "${var.project}-${var.env}-external-dns"
  assume_role_policy = data.aws_iam_policy_document.trust.json

  tags = {
    Project     = var.project
    Environment = var.env
  }
}

# ── Route53 permissions ───────────────────────────────────────────────────────
data "aws_iam_policy_document" "external_dns" {
  statement {
    sid       = "ChangeOwnZoneRecords"
    effect    = "Allow"
    actions   = ["route53:ChangeResourceRecordSets"]
    resources = ["arn:aws:route53:::hostedzone/${var.route53_zone_id}"]
    # Scoped to only the one hosted zone this project owns.
  }

  statement {
    sid    = "ListZonesAndRecords"
    effect = "Allow"
    actions = [
      "route53:ListHostedZones",
      "route53:ListResourceRecordSets",
    ]
    resources = ["*"]
    # AWS does not support resource-level ARNs for these List* actions —
    # external-dns needs them to discover which zone matches its domain
    # filter before it can write records into it.
  }
}

resource "aws_iam_role_policy" "external_dns" {
  name   = "route53-access"
  role   = aws_iam_role.external_dns.id
  policy = data.aws_iam_policy_document.external_dns.json
}

resource "kubernetes_service_account" "external_dns" {
  metadata {
    name      = local.service_account_name
    namespace = kubernetes_namespace.external_dns.metadata[0].name

    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.external_dns.arn
    }
  }
}

# ── Helm release ──────────────────────────────────────────────────────────────
resource "helm_release" "external_dns" {
  name       = "external-dns"
  repository = "https://kubernetes-sigs.github.io/external-dns/"
  chart      = "external-dns"
  version    = var.chart_version
  namespace  = kubernetes_namespace.external_dns.metadata[0].name

  values = [
    yamlencode({
      provider = { name = "aws" }

      aws = {
        zoneType = "public"
      }

      domainFilters = [var.domain_filter]
      # Only ever touches records under this domain — a bug here can't
      # accidentally modify DNS for an unrelated zone.

      txtOwnerId = "${var.project}-${var.env}"
      # Ownership TXT records let external-dns tell "records it created"
      # apart from anything else in the zone, so sync mode only ever
      # touches its own records.

      policy = "sync"
      # sync (not upsert-only): also removes DNS records when the matching
      # Ingress is deleted, so stale records pointing at dead endpoints —
      # the exact GoDaddy problem this project just hit — can't happen again.

      sources = ["ingress"]

      # ArgoCD and Grafana each have TWO Ingress objects for the same
      # hostname: their own (ingressClassName: nginx, internal routing only)
      # and the shared one in modules/cluster-ingress (ingressClassName: alb,
      # the real public entry point). Without this filter, external-dns finds
      # both and may pick the nginx one — which reports nginx's own ClusterIP
      # in its status, not a real public address. Restricting the source to
      # the "alb" class ensures external-dns only ever reads the one Ingress
      # that actually has the ALB's DNS name in its status.
      extraArgs = ["--ingress-class=alb"]

      serviceAccount = {
        create = false
        name   = kubernetes_service_account.external_dns.metadata[0].name
      }

      resources = {
        requests = { cpu = "50m", memory = "64Mi" }
        limits   = { cpu = "100m", memory = "128Mi" }
      }
    })
  ]

  depends_on = [kubernetes_service_account.external_dns, aws_iam_role_policy.external_dns]
}
