# ACM Certificate for HTTPS (conditional)
resource "aws_acm_certificate" "main" {
  count             = var.enable_https && var.app_domain != "" ? 1 : 0
  domain_name       = var.app_domain
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "samsung-logistics-cert"
  }
}

# Route53 record for certificate validation
resource "aws_route53_record" "cert_validation" {
  count   = var.enable_https && var.app_domain != "" ? 1 : 0
  name    = tolist(aws_acm_certificate.main[0].domain_validation_options)[0].resource_record_name
  type    = tolist(aws_acm_certificate.main[0].domain_validation_options)[0].resource_record_type
  records = [tolist(aws_acm_certificate.main[0].domain_validation_options)[0].resource_record_value]
  zone_id = data.aws_route53_zone.main[0].zone_id
  ttl     = 60
}

# Route53 zone lookup
data "aws_route53_zone" "main" {
  count        = var.enable_https && var.app_domain != "" ? 1 : 0
  name         = join(".", slice(split(".", var.app_domain), 1, length(split(".", var.app_domain))))
  private_zone = false
}

# Certificate validation
resource "aws_acm_certificate_validation" "main" {
  count           = var.enable_https && var.app_domain != "" ? 1 : 0
  certificate_arn = aws_acm_certificate.main[0].arn
  validation_record_fqdns = [aws_route53_record.cert_validation[0].fqdn]

  timeouts {
    create = "5m"
  }
}
