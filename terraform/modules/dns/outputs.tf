output "zone_id" {
  description = "Route53 hosted zone ID — used by external-dns and for ACM DNS validation"
  value       = aws_route53_zone.main.zone_id
}

output "name_servers" {
  description = "Nameservers for this zone — delegate GoDaddy's nameserver records for the domain to these"
  value       = aws_route53_zone.main.name_servers
}
