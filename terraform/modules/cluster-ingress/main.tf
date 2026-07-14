# ── ACM certificate ───────────────────────────────────────────────────────────
# Regional cert (not us-east-1) — ALB certificates must live in the same
# region as the ALB, unlike CloudFront which hard-requires us-east-1.
# DNS-validated automatically via the Route53 zone from modules/dns — no more
# manually pasting CNAME records into GoDaddy to validate a certificate.

resource "aws_acm_certificate" "cluster" {
  domain_name               = var.argocd_hostname
  subject_alternative_names = [var.grafana_hostname]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Project     = var.project
    Environment = var.env
    Name        = "${var.project}-${var.env}-cluster-cert"
  }
}

resource "aws_route53_record" "cluster_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.cluster.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id         = var.route53_zone_id
  name            = each.value.name
  type            = each.value.type
  records         = [each.value.record]
  ttl             = 60
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "cluster" {
  certificate_arn         = aws_acm_certificate.cluster.arn
  validation_record_fqdns = [for r in aws_route53_record.cluster_cert_validation : r.fqdn]
}

# ── Shared ALB Ingress ────────────────────────────────────────────────────────
# Single entry point for ArgoCD and Grafana. Terminates TLS here (regional
# ACM cert above) and forwards everything to the nginx ingress controller,
# which owns the actual host/path routing to each app's real backend Service —
# see modules/argocd and modules/monitoring, both on ingressClassName: nginx.
resource "kubernetes_ingress_v1" "shared" {
  metadata {
    name      = "shared-alb"
    namespace = var.nginx_namespace
    # Lives in the same namespace as the nginx Service so it can reference it
    # directly — an Ingress backend can only target a Service in its own
    # namespace.

    annotations = {
      "alb.ingress.kubernetes.io/scheme"          = "internet-facing"
      "alb.ingress.kubernetes.io/target-type"     = "ip"
      "alb.ingress.kubernetes.io/certificate-arn" = aws_acm_certificate_validation.cluster.certificate_arn
      "alb.ingress.kubernetes.io/listen-ports"    = jsonencode([{ "HTTP" = 80 }, { "HTTPS" = 443 }])
      # No ssl-redirect annotation here on purpose. This ALB is shared (via
      # group.name below) with gitflow-analyzer-production's Ingress, and
      # AWS Load Balancer Controller implements ssl-redirect as the
      # listener's condition-less default action — i.e. it isn't scoped to
      # this Ingress's own hosts, it redirects everything on the shared ALB.
      # That broke CloudFront's deliberate plain-HTTP calls to result-api
      # (modules/frontend-cdn terminates TLS itself and proxies to the ALB
      # over HTTP). HTTPS enforcement for ArgoCD/Grafana now happens at the
      # nginx layer instead — see force-ssl-redirect in modules/argocd and
      # modules/monitoring.
      # Default health check (GET / on port 80) hits nginx with no Host
      # header nginx recognizes, so nginx's default backend returns 404 and
      # the ALB marks every target unhealthy. nginx always serves a real
      # /healthz on 10254 regardless of Host — point the health check there
      # instead of the traffic port.
      "alb.ingress.kubernetes.io/healthcheck-path" = "/healthz"
      "alb.ingress.kubernetes.io/healthcheck-port" = "10254"
      # modules/alb-lookup finds this ALB by tag (ingress.k8s.aws/stack),
      # which the AWS Load Balancer Controller sets from group.name. Without
      # this, it defaults to "<namespace>/<ingress-name>" and alb-lookup
      # (and therefore frontend-cdn's API proxy origin) can no longer find
      # the ALB at all. Keep this pinned to "gitflow-analyzer" — the same
      # value the old per-app Ingress objects used — so nothing downstream
      # has to change.
      "alb.ingress.kubernetes.io/group.name" = "gitflow-analyzer"
    }
  }

  spec {
    ingress_class_name = "alb"

    rule {
      host = var.argocd_hostname
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = var.nginx_service_name
              port {
                number = 80
              }
            }
          }
        }
      }
    }

    rule {
      host = var.grafana_hostname
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = var.nginx_service_name
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }
}
