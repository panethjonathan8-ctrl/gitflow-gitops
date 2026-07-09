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
          # TLS is terminated at CloudFront — ArgoCD itself speaks plain HTTP.
          "server.insecure" = "true"
        }
        cm = {
          # Must match the public URL so Dex generates correct redirect URIs.
          url = "https://${var.argocd_hostname}"
        }
        secret = {
          # Injects dex.github.clientSecret into argocd-secret so the Dex
          # config below can reference it with $dex.github.clientSecret without
          # embedding the plaintext value in argocd-cm (a non-secret ConfigMap).
          extra = {
            "dex.github.clientSecret" = var.argocd_github_oauth_client_secret
          }
        }
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
          # The ALB Ingress below becomes the only public entry point.
          # This replaces the previous LoadBalancer (NLB) — saving ~$16/month.
          type = "ClusterIP"
        }
        ingress = {
          enabled          = true
          ingressClassName = "alb"
          annotations = {
            "alb.ingress.kubernetes.io/scheme"      = "internet-facing"
            "alb.ingress.kubernetes.io/target-type" = "ip"
            # Joins the shared ALB used by the app and Grafana.
            # One ALB serves all three hostnames — no extra load balancer cost.
            "alb.ingress.kubernetes.io/group.name"  = "gitflow-analyzer"
            "alb.ingress.kubernetes.io/group.order" = "15"
          }
          hosts = [var.argocd_hostname]
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
