locals {
  oidc_host                 = replace(var.oidc_issuer_url, "https://", "")
  namespace                 = "eso"
  service_account_name      = "eso"
  cluster_secret_store_name = "aws-secrets-manager"
}

resource "kubernetes_namespace" "eso" {
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
# Same IRSA pattern as modules/external-dns and modules/aws-lb-controller,
# scoped to eso's own service account instead.
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

resource "aws_iam_role" "eso" {
  name               = "${var.project}-${var.env}-eso"
  assume_role_policy = data.aws_iam_policy_document.trust.json

  tags = {
    Project     = var.project
    Environment = var.env
  }
}

# ── Secrets Manager permission ────────────────────────────────────────────────
# Same actions and ARN-prefix scoping as modules/secrets' read_secrets policy —
# eso reads on behalf of every consumer (argocd, monitoring, ...), so it is
# scoped to the whole project rather than a single environment.
data "aws_iam_policy_document" "secrets_read" {
  statement {
    sid    = "ReadProjectSecrets"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
    ]
    resources = ["arn:aws:secretsmanager:*:*:secret:${var.project}/*"]
  }
}

resource "aws_iam_role_policy" "secrets_read" {
  name   = "secrets-manager-read"
  role   = aws_iam_role.eso.id
  policy = data.aws_iam_policy_document.secrets_read.json
}

resource "kubernetes_service_account" "eso" {
  metadata {
    name      = local.service_account_name
    namespace = kubernetes_namespace.eso.metadata[0].name

    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.eso.arn
    }
  }
}

# ── Helm release ──────────────────────────────────────────────────────────────
resource "helm_release" "eso" {
  name       = "external-secrets"
  repository = "https://charts.external-secrets.io"
  chart      = "external-secrets"
  version    = var.chart_version
  namespace  = kubernetes_namespace.eso.metadata[0].name

  values = [
    yamlencode({
      installCRDs = true

      serviceAccount = {
        create = false
        name   = kubernetes_service_account.eso.metadata[0].name
      }

      resources = {
        requests = { cpu = "50m", memory = "64Mi" }
        limits   = { cpu = "100m", memory = "128Mi" }
      }
    })
  ]

  depends_on = [kubernetes_service_account.eso, aws_iam_role_policy.secrets_read]
}

# ── ClusterSecretStore ────────────────────────────────────────────────────────
# Cluster-scoped (not namespaced) so both the argocd and monitoring namespaces
# can reference the same store from their ExternalSecret resources. Auth uses
# the eso service account's IRSA role above — no static AWS credentials.
#
# kubernetes_manifest reads the CRD's schema from the API server at plan time.
# On a from-scratch cluster the CRD does not exist until helm_release.eso has
# actually applied — so the very first `terragrunt apply` on this unit fails
# to plan this resource, and needs to be re-run once the helm release has
# landed. Same class of bootstrap-ordering limitation as modules/alb-lookup.
resource "kubernetes_manifest" "cluster_secret_store" {
  manifest = {
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ClusterSecretStore"
    metadata = {
      name = local.cluster_secret_store_name
    }
    spec = {
      provider = {
        aws = {
          service = "SecretsManager"
          region  = var.aws_region
          auth = {
            jwt = {
              serviceAccountRef = {
                name      = kubernetes_service_account.eso.metadata[0].name
                namespace = kubernetes_namespace.eso.metadata[0].name
              }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.eso]
}
