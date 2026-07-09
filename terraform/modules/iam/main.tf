# ── OIDC Provider ─────────────────────────────────────────────────────────────
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
  # This tells AWS to trust JWT tokens issued by GitHub Actions.
  # Without this, AWS has no idea who GitHub is and will reject all requests.
  count = var.create_oidc_provider ? 1 : 0

  client_id_list = ["sts.amazonaws.com"]
  # This says the tokens are intended for AWS STS specifically.
  # STS is the service that issues temporary credentials.

  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
  # This is GitHub's TLS certificate thumbprint.
  # AWS uses it to verify the token actually came from GitHub and not an impersonator.
  # This value is fixed and published by GitHub — it does not change often.
}
# ── IAM Role ──────────────────────────────────────────────────────────────────
resource "aws_iam_role" "github_actions" {
  name = "${var.project}-github-actions-${var.env}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = var.create_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : "arn:aws:iam::${var.aws_account_id}:oidc-provider/token.actions.githubusercontent.com"
          # The principal is the OIDC provider, not a user or service.
          # This means only tokens from GitHub can trigger this assume role.
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            # This is the critical security line.
            # Only YOUR specific repo on YOUR GitHub account can assume this role.
            # If anyone else tries from a different repo, AWS rejects it.
            # The :ref:refs/heads/* part means any branch can trigger it.
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_username}/${var.github_repo}:*"
          }
        }
      }
    ]
  })

  tags = {
    Project     = var.project
    Environment = var.env
  }
}

# ── Policy: ECR access ────────────────────────────────────────────────────────
resource "aws_iam_role_policy" "ecr" {
  name = "ecr-push-pull"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ECRAuth"
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
        # GetAuthorizationToken cannot be scoped to a specific repo —
        # it must be * because it returns a token for the whole registry.
      },
      {
        Sid    = "ECRPushPull"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer"
        ]
        # Scoped to only your project's ECR repos — not every repo in the account.
        Resource = "arn:aws:ecr:*:${var.aws_account_id}:repository/${var.project}/*"
      }
    ]
  })
}

# ── Policy: EKS access for kubectl ────────────────────────────────────────────
# Only what "aws eks update-kubeconfig" + the deploy pipeline's kubectl calls
# need. `terraform_infra`'s old eks:* (and ec2:*, iam:*, secretsmanager:*,
# terraform-state S3 access) are gone: this role no longer runs terraform or
# terragrunt at all — that's an explicitly human-run, local-only operation
# (see CLAUDE.md), so CI never needs those broad permissions. Scoped to the
# dev cluster; add other cluster ARNs here if this role is ever reused for
# more than one cluster.
resource "aws_iam_role_policy" "eks_describe" {
  name = "eks-describe"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "EKSDescribe"
        Effect   = "Allow"
        Action   = ["eks:DescribeCluster"]
        Resource = "arn:aws:eks:*:${var.aws_account_id}:cluster/${var.project}-dev"
      }
    ]
  })
}

# ── Policy: Frontend S3 upload + CloudFront invalidation ────────────────────
# Narrower than the old frontend_cdn policy: this role only ever runs
# `aws s3 cp` to upload the built frontend and invalidates the CloudFront
# cache — it never creates/deletes the bucket or distribution (that's
# terraform's job, run locally, not from CI).
resource "aws_iam_role_policy" "frontend_deploy" {
  name = "frontend-deploy"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "FrontendS3Upload"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.project}-frontend-*",
          "arn:aws:s3:::${var.project}-frontend-*/*"
        ]
      },
      {
        Sid    = "CloudFrontInvalidate"
        Effect = "Allow"
        Action = [
          "cloudfront:CreateInvalidation",
          "cloudfront:GetInvalidation"
        ]
        # CloudFront does not support resource-level ARNs for these actions.
        Resource = "*"
      },
      {
        Sid    = "SSMParameterRead"
        Effect = "Allow"
        Action = ["ssm:GetParameter"]
        # Reads the CloudFront distribution ID written by terraform — scoped
        # to this project's parameters only.
        Resource = "arn:aws:ssm:*:${var.aws_account_id}:parameter/${var.project}/*"
      }
    ]
  })
}
