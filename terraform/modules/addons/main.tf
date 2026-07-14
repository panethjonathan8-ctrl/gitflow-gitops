locals {
  oidc_host = replace(var.oidc_issuer_url, "https://", "")
}

# ═════════════════════════════════════════════════════════════════════════════
# AWS Load Balancer Controller
# Watches Ingress objects with ingressClassName: alb and creates/manages the
# real ALB (see modules/cluster-ingress) in response. Runs in kube-system by
# convention — cluster infrastructure, not application code.
# ═════════════════════════════════════════════════════════════════════════════

data "aws_iam_policy_document" "lb_controller_trust" {
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
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lb_controller" {
  name               = "${var.project}-${var.env}-lb-controller"
  assume_role_policy = data.aws_iam_policy_document.lb_controller_trust.json

  tags = {
    Project     = var.project
    Environment = var.env
  }
}

# The controller calls EC2 and ELB APIs to create and manage ALBs on your behalf.
# Each statement group maps to a specific controller action. Many require
# resources = "*" because AWS does not support resource-level ARNs for these
# describe/list actions — documented per statement, not a blanket shortcut.
data "aws_iam_policy_document" "lb_controller" {
  statement {
    sid    = "ReadNetworkTopology"
    effect = "Allow"
    actions = [
      "ec2:DescribeAccountAttributes",
      "ec2:DescribeAddresses",
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeInternetGateways",
      "ec2:DescribeVpcs",
      "ec2:DescribeVpcPeeringConnections",
      "ec2:DescribeSubnets",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeInstances",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeTags",
      "ec2:GetCoipPoolUsage",
      "ec2:DescribeCoipPools",
    ]
    resources = ["*"]
    # EC2 describe actions cannot be scoped to specific resources — AWS requires *.
  }

  statement {
    sid    = "ManageSecurityGroups"
    effect = "Allow"
    actions = [
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupIngress",
      "ec2:CreateSecurityGroup",
      "ec2:DeleteSecurityGroup",
    ]
    resources = ["*"]
  }

  statement {
    sid     = "TagSecurityGroupsAndENIs"
    effect  = "Allow"
    actions = ["ec2:CreateTags", "ec2:DeleteTags"]
    resources = [
      "arn:aws:ec2:*:*:security-group/*",
      "arn:aws:ec2:*:*:network-interface/*",
    ]
  }

  statement {
    sid    = "ManageLoadBalancers"
    effect = "Allow"
    actions = [
      "elasticloadbalancing:AddListenerCertificates",
      "elasticloadbalancing:AddTags",
      "elasticloadbalancing:CreateListener",
      "elasticloadbalancing:CreateLoadBalancer",
      "elasticloadbalancing:CreateRule",
      "elasticloadbalancing:CreateTargetGroup",
      "elasticloadbalancing:DeleteListener",
      "elasticloadbalancing:DeleteLoadBalancer",
      "elasticloadbalancing:DeleteRule",
      "elasticloadbalancing:DeleteTargetGroup",
      "elasticloadbalancing:DeregisterTargets",
      "elasticloadbalancing:DescribeListenerCertificates",
      "elasticloadbalancing:DescribeListeners",
      "elasticloadbalancing:DescribeLoadBalancers",
      "elasticloadbalancing:DescribeLoadBalancerAttributes",
      "elasticloadbalancing:DescribeRules",
      "elasticloadbalancing:DescribeSSLPolicies",
      "elasticloadbalancing:DescribeTags",
      "elasticloadbalancing:DescribeTargetGroups",
      "elasticloadbalancing:DescribeTargetGroupAttributes",
      "elasticloadbalancing:DescribeTargetHealth",
      "elasticloadbalancing:ModifyListener",
      "elasticloadbalancing:ModifyLoadBalancerAttributes",
      "elasticloadbalancing:ModifyRule",
      "elasticloadbalancing:ModifyTargetGroup",
      "elasticloadbalancing:ModifyTargetGroupAttributes",
      "elasticloadbalancing:RegisterTargets",
      "elasticloadbalancing:RemoveListenerCertificates",
      "elasticloadbalancing:RemoveTags",
      "elasticloadbalancing:SetIpAddressType",
      "elasticloadbalancing:SetSecurityGroups",
      "elasticloadbalancing:SetSubnets",
      "elasticloadbalancing:SetWebAcl",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ReadCertificates"
    effect = "Allow"
    actions = [
      "acm:DescribeCertificate",
      "acm:ListCertificates",
      "acm:GetCertificate",
    ]
    resources = ["*"]
  }

  statement {
    sid       = "CreateELBServiceLinkedRole"
    effect    = "Allow"
    actions   = ["iam:CreateServiceLinkedRole"]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "iam:AWSServiceName"
      values   = ["elasticloadbalancing.amazonaws.com"]
      # Prevents this permission from being used to create service-linked roles
      # for any other AWS service — scoped to ELB only.
    }
  }

  statement {
    sid    = "ReadIAMCertificates"
    effect = "Allow"
    actions = [
      "iam:GetServerCertificate",
      "iam:ListServerCertificates",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ManageWAF"
    effect = "Allow"
    actions = [
      "waf-regional:GetWebACL",
      "waf-regional:GetWebACLForResource",
      "waf-regional:AssociateWebACL",
      "waf-regional:DisassociateWebACL",
      "wafv2:GetWebACL",
      "wafv2:GetWebACLForResource",
      "wafv2:AssociateWebACL",
      "wafv2:DisassociateWebACL",
      "waf:GetWebACL",
    ]
    resources = ["*"]
  }

  statement {
    sid       = "ReadCognito"
    effect    = "Allow"
    actions   = ["cognito-idp:DescribeUserPoolClient"]
    resources = ["*"]
  }

  statement {
    sid    = "ReadShield"
    effect = "Allow"
    actions = [
      "shield:GetSubscriptionState",
      "shield:DescribeProtection",
      "shield:CreateProtection",
      "shield:DeleteProtection",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "lb_controller" {
  name   = "${var.project}-${var.env}-lb-controller"
  policy = data.aws_iam_policy_document.lb_controller.json

  tags = {
    Project     = var.project
    Environment = var.env
  }
}

resource "aws_iam_role_policy_attachment" "lb_controller" {
  role       = aws_iam_role.lb_controller.name
  policy_arn = aws_iam_policy.lb_controller.arn
}

resource "helm_release" "lb_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = var.lb_controller_chart_version
  namespace  = "kube-system"

  set {
    name  = "clusterName"
    value = var.cluster_name
  }

  set {
    name  = "region"
    value = var.aws_region
  }

  set {
    name  = "vpcId"
    value = var.vpc_id
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.lb_controller.arn
  }

  depends_on = [aws_iam_role_policy_attachment.lb_controller]
  # The IAM role must have its policy attached before the controller starts,
  # otherwise it launches but immediately fails all API calls.
}

# ═════════════════════════════════════════════════════════════════════════════
# ingress-nginx
# Runs as ClusterIP, not its own LoadBalancer — the shared ALB (modules/
# cluster-ingress) targets these pods directly via target-type: ip, so there
# is no second AWS load balancer and no added cost.
# ═════════════════════════════════════════════════════════════════════════════

resource "kubernetes_namespace" "ingress_nginx" {
  metadata {
    name = "ingress-nginx"
    labels = {
      Project                        = var.project
      Environment                    = var.env
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

resource "helm_release" "ingress_nginx" {
  name       = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = var.ingress_nginx_chart_version
  namespace  = kubernetes_namespace.ingress_nginx.metadata[0].name

  values = [
    yamlencode({
      controller = {
        ingressClassResource = {
          name    = "nginx"
          default = false
          # default: false — "alb" stays the cluster's default ingress class
          # so nothing switches class by accident. Apps opt into nginx
          # explicitly via ingressClassName.
        }

        service = {
          type = "ClusterIP"
        }

        resources = {
          requests = { cpu = "100m", memory = "128Mi" }
          limits   = { cpu = "200m", memory = "256Mi" }
        }
      }
    })
  ]

  depends_on = [kubernetes_namespace.ingress_nginx, helm_release.lb_controller]
  # Also depends on lb_controller: its mutating webhook intercepts every
  # Service object cluster-wide (not just LoadBalancer-type), so creating
  # this Service before the webhook pod is ready fails with "no endpoints
  # available for service aws-load-balancer-webhook-service". helm_release
  # defaults to wait = true, so by the time lb_controller shows as created,
  # its webhook is actually serving.
}

# ═════════════════════════════════════════════════════════════════════════════
# external-dns
# Watches Ingress objects and keeps Route53 in sync with the shared ALB's
# actual DNS name — self-healing, no manual GoDaddy/Route53 updates needed.
# ═════════════════════════════════════════════════════════════════════════════

resource "kubernetes_namespace" "external_dns" {
  metadata {
    name = "external-dns"
    labels = {
      Project                        = var.project
      Environment                    = var.env
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

data "aws_iam_policy_document" "external_dns_trust" {
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
      values   = ["system:serviceaccount:external-dns:external-dns"]
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
  assume_role_policy = data.aws_iam_policy_document.external_dns_trust.json

  tags = {
    Project     = var.project
    Environment = var.env
  }
}

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
    name      = "external-dns"
    namespace = kubernetes_namespace.external_dns.metadata[0].name

    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.external_dns.arn
    }
  }
}

resource "helm_release" "external_dns" {
  name       = "external-dns"
  repository = "https://kubernetes-sigs.github.io/external-dns/"
  chart      = "external-dns"
  version    = var.external_dns_chart_version
  namespace  = kubernetes_namespace.external_dns.metadata[0].name

  values = [
    yamlencode({
      provider = { name = "aws" }

      aws = {
        zoneType = "public"
      }

      domainFilters = [var.domain_filter]
      txtOwnerId    = "${var.project}-${var.env}"
      policy        = "sync"
      sources       = ["ingress"]

      # ArgoCD and Grafana each have TWO Ingress objects for the same
      # hostname: their own (ingressClassName: nginx, internal routing only)
      # and the shared one in modules/cluster-ingress (ingressClassName: alb,
      # the real public entry point). This filter ensures external-dns only
      # ever reads the one Ingress that actually has the ALB's DNS name in
      # its status.
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

  depends_on = [kubernetes_service_account.external_dns, aws_iam_role_policy.external_dns, helm_release.lb_controller]
  # See helm_release.ingress_nginx for why this also depends on lb_controller.
}

# ═════════════════════════════════════════════════════════════════════════════
# External Secrets Operator (ESO)
# Syncs AWS Secrets Manager entries into Kubernetes Secrets — see modules/
# argocd and modules/monitoring for the ExternalSecret resources that consume
# the ClusterSecretStore created below.
# ═════════════════════════════════════════════════════════════════════════════

resource "kubernetes_namespace" "eso" {
  metadata {
    name = "eso"
    labels = {
      Project                        = var.project
      Environment                    = var.env
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

data "aws_iam_policy_document" "eso_trust" {
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
      values   = ["system:serviceaccount:eso:eso"]
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
  assume_role_policy = data.aws_iam_policy_document.eso_trust.json

  tags = {
    Project     = var.project
    Environment = var.env
  }
}

data "aws_iam_policy_document" "eso_secrets_read" {
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

resource "aws_iam_role_policy" "eso_secrets_read" {
  name   = "secrets-manager-read"
  role   = aws_iam_role.eso.id
  policy = data.aws_iam_policy_document.eso_secrets_read.json
}

resource "kubernetes_service_account" "eso" {
  metadata {
    name      = "eso"
    namespace = kubernetes_namespace.eso.metadata[0].name

    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.eso.arn
    }
  }
}

resource "helm_release" "eso" {
  name       = "external-secrets"
  repository = "https://charts.external-secrets.io"
  chart      = "external-secrets"
  version    = var.eso_chart_version
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

  depends_on = [kubernetes_service_account.eso, aws_iam_role_policy.eso_secrets_read, helm_release.lb_controller]
  # See helm_release.ingress_nginx for why this also depends on lb_controller.
}

# ── ClusterSecretStore ────────────────────────────────────────────────────────
# Cluster-scoped so both the argocd and monitoring namespaces can reference
# the same store. Auth uses the eso service account's IRSA role — no static
# AWS credentials.
#
# kubernetes_manifest would validate this CRD's schema at plan time — before
# helm_release.eso (same apply) has installed it, so it can never plan on a
# from-scratch cluster. local-exec runs only at apply time, after the CRD
# already exists, so this works in one ordinary `terragrunt apply`, first try.
resource "null_resource" "cluster_secret_store" {
  depends_on = [helm_release.eso]

  triggers = {
    cluster_name  = var.cluster_name
    aws_region    = var.aws_region
    eso_role_arn  = aws_iam_role.eso.arn
    eso_namespace = kubernetes_namespace.eso.metadata[0].name
  }

  provisioner "local-exec" {
    command = <<-EOT
      aws eks update-kubeconfig \
        --name ${var.cluster_name} \
        --region ${var.aws_region} \
        --kubeconfig /tmp/kubeconfig-${var.cluster_name}

      KUBECONFIG=/tmp/kubeconfig-${var.cluster_name} kubectl apply -f - <<'YAML'
      apiVersion: external-secrets.io/v1
      kind: ClusterSecretStore
      metadata:
        name: aws-secrets-manager
      spec:
        provider:
          aws:
            service: SecretsManager
            region: ${var.aws_region}
            auth:
              jwt:
                serviceAccountRef:
                  name: eso
                  namespace: eso
      YAML

      rm -f /tmp/kubeconfig-${var.cluster_name}
    EOT
  }
}
