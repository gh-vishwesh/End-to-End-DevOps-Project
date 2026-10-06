# Optional: public hosted zone + DNS-validated ACM certificate for HTTPS on the ALB.
# Enabled only when var.domain_name is set (root variable "domain_name").
# After apply, point your registrar's name servers at the output route53_name_servers,
# otherwise certificate validation waits until the timeout.

variable "domain_name" {
  type    = string
  default = ""
}

locals {
  enabled = var.domain_name != ""
}

resource "aws_route53_zone" "dns" {
  count = local.enabled ? 1 : 0
  name  = var.domain_name
}

resource "aws_acm_certificate" "ssl" {
  count             = local.enabled ? 1 : 0
  domain_name       = var.domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "certificate" {
  for_each = local.enabled ? {
    for dvo in aws_acm_certificate.ssl[0].domain_validation_options :
    dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}
  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.dns[0].zone_id
}

resource "aws_acm_certificate_validation" "ssl_valid" {
  count                   = local.enabled ? 1 : 0
  certificate_arn         = aws_acm_certificate.ssl[0].arn
  validation_record_fqdns = [for record in aws_route53_record.certificate : record.fqdn]
  timeouts {
    create = "30m"
  }
}

output "certificate_arn" {
  value = local.enabled ? aws_acm_certificate_validation.ssl_valid[0].certificate_arn : ""
}

output "name_servers" {
  value = local.enabled ? aws_route53_zone.dns[0].name_servers : []
}

output "zone_id" {
  value = local.enabled ? aws_route53_zone.dns[0].zone_id : ""
}
