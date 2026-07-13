# ── ArgoCD Namespace ──────────────────────────────────────────────────────────
resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"

    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      Project                        = var.project
      Environment                    = var.env
    }
  }
}

# ── ArgoCD Helm Release ───────────────────────────────────────────────────────
resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_chart_version
  namespace  = kubernetes_namespace.argocd.metadata[0].name

  timeout = 600
  wait    = false
  # wait = false because ArgoCD has many components and Terraform's Helm provider
  # consistently times out waiting for them even when all pods are Running.
  # ArgoCD comes up reliably on its own — verified across multiple applies.
  # The argocd kubernetes_namespace resource below is what ensures the namespace
  # exists before any downstream resources reference it.

  values = [
    yamlencode({
      # global.domain is the primary domain setting in ArgoCD chart 7.x —
      # it controls the ingress host rule, the Dex redirect URI base, and
      # the server URL. server.ingress.hosts alone is not enough in this chart version.
      global = {
        domain = var.argocd_hostname
      }

      configs = {
        params = {
          # TLS is terminated at the ALB (see modules/cluster-ingress) —
          # ArgoCD itself speaks plain HTTP.
          "server.insecure" = "true"
        }
        cm = {
          # Must match the public URL so Dex generates correct redirect URIs.
          url = "https://${var.argocd_hostname}"
        }
        # dex.github.clientSecret is no longer set here. It used to be passed
        # straight from a Terraform variable into argocd-secret, which put the
        # plaintext value in Terraform state. The ExternalSecret resource
        # below merges it into the same argocd-secret key directly from
        # Secrets Manager instead — see kubernetes_manifest.argocd_github_oauth.
        rbac = {
          # Only the allowed GitHub user gets admin. Everyone else gets role:''
          # which means no permissions — they see the login page but can't enter.
          "policy.csv"     = "g, ${var.argocd_github_allowed_user}, role:admin\n"
          "policy.default" = "role:''"
          # preferred_username is the JWT claim Dex sets to the GitHub login.
          # Without it in scopes, ArgoCD only checks the groups claim (empty
          # when no GitHub org is configured), so g, <username> never matches.
          "scopes" = "[groups, preferred_username]"
        }
      }

      server = {
        service = {
          # ClusterIP means the pod is only reachable inside the cluster.
          # nginx (ingressClassName below) is the only thing that talks to it
          # directly; the shared ALB in modules/cluster-ingress talks to nginx.
          # This replaces the previous LoadBalancer (NLB) — saving ~$16/month.
          type = "ClusterIP"
        }
        ingress = {
          enabled = true
          # Routing is now ALB -> nginx -> here (see modules/cluster-ingress
          # for the shared ALB/TLS and modules/addons for the
          # controller). No AWS-specific annotations needed — nginx owns the
          # actual routing decision.
          ingressClassName = "nginx"
          hosts            = [var.argocd_hostname]
        }
      }
    }),

    # Dex connector config — written as raw YAML so the block scalar (|) is
    # preserved exactly as ArgoCD expects it in argocd-cm.
    # $dex.github.clientSecret is an ArgoCD substitution — at runtime ArgoCD
    # reads the value from argocd-secret and injects it here.
    <<-YAML
      configs:
        cm:
          dex.config: |
            connectors:
              - type: github
                id: github
                name: GitHub
                config:
                  clientID: ${var.argocd_github_oauth_client_id}
                  clientSecret: $dex.github.clientSecret
                  redirectURI: https://${var.argocd_hostname}/api/dex/callback
    YAML
  ]
}

# ── GitHub OAuth client secret (synced from Secrets Manager) ─────────────────
# creationPolicy = Merge adds the dex.github.clientSecret key into the
# argocd-secret Secret that the Helm release above already owns/creates,
# instead of ESO owning a separate Secret object. The value itself lives only
# in Secrets Manager — set it once with:
#   aws secretsmanager put-secret-value \
#     --secret-id ${var.project}/${var.env}/argocd-github-oauth-client-secret \
#     --secret-string '<value>'
resource "kubernetes_manifest" "argocd_github_oauth" {
  manifest = {
    apiVersion = "external-secrets.io/v1"
    kind       = "ExternalSecret"
    metadata = {
      name      = "argocd-github-oauth"
      namespace = kubernetes_namespace.argocd.metadata[0].name
    }
    spec = {
      refreshInterval = "1h"
      secretStoreRef = {
        kind = "ClusterSecretStore"
        name = var.cluster_secret_store
      }
      target = {
        name           = "argocd-secret"
        creationPolicy = "Merge"
      }
      data = [
        {
          secretKey = "dex.github.clientSecret"
          remoteRef = {
            key = "${var.project}/${var.env}/argocd-github-oauth-client-secret"
          }
        }
      ]
    }
  }

  depends_on = [helm_release.argocd]
}

# ── ArgoCD Application cleanup ────────────────────────────────────────────────
# Registering the Applications (kubectl apply -f k8s/argocd/application-*.yaml)
# used to happen here via a local-exec provisioner reading
# "${path.root}/../../../k8s/argocd/*.yaml" — a hardcoded relative path that
# assumed Terraform and k8s/ lived in the same checkout at a fixed depth. That
# broke once this module started running under Terragrunt (module source is
# copied into a .terragrunt-cache temp dir, so path.root no longer points at
# the real repo checkout) and would have been structurally broken by the
# gitflow-app/gitflow-gitops repo split regardless — the Application manifests
# now live in a different repo than this Terraform module.
#
# Registration now happens exclusively in gitflow-app's deploy pipeline
# (scripts/bootstrap-argocd.sh), which checks out gitflow-gitops explicitly
# and applies the manifests from there — see gitflow-app's deploy.yml.
#
# This resource keeps only the destroy-time cleanup, which is name-based (no
# file paths, nothing to break): it clears Application finalizers before the
# ArgoCD Helm release is deleted, so nightly cluster teardown doesn't leave
# namespaces stuck in Terminating.
resource "null_resource" "argocd_application_cleanup" {
  depends_on = [helm_release.argocd]

  triggers = {
    cluster_name = var.cluster_name
    aws_region   = var.aws_region
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      aws eks update-kubeconfig --name "${self.triggers.cluster_name}" --region "${self.triggers.aws_region}" || true
      for app in gitflow-analyzer-dev gitflow-analyzer-staging gitflow-analyzer-production grafana-dashboards gitflow-analyzer; do
        kubectl patch application "$app" -n argocd \
          -p '{"metadata":{"finalizers":[]}}' --type=merge 2>/dev/null || true
        kubectl delete application "$app" -n argocd --ignore-not-found=true 2>/dev/null || true
      done
      echo "ArgoCD Application finalizers cleared"
    EOT
  }
}
