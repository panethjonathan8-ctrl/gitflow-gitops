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

# ── nginx Ingress Controller ───────────────────────────────────────────────────
# Runs as ClusterIP, not its own LoadBalancer — the existing shared ALB (see
# modules/cluster-ingress) targets these pods directly via target-type: ip,
# so there is no second AWS load balancer and no added cost.
resource "helm_release" "ingress_nginx" {
  name       = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = var.chart_version
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

  depends_on = [kubernetes_namespace.ingress_nginx]
}
