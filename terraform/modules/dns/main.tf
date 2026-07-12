# ── Route53 hosted zone ────────────────────────────────────────────────────────
# GoDaddy stays the domain registrar — only DNS hosting moves here. Once this
# zone exists, delegate it by pointing GoDaddy's nameserver records at the
# name_servers output below. external-dns (see modules/external-dns) and the
# ACM certificate in modules/cluster-ingress both write into this zone.

resource "aws_route53_zone" "main" {
  name = var.domain_name

  tags = {
    Project     = var.project
    Environment = var.env
    Name        = "${var.project}-${var.env}-zone"
  }
}
