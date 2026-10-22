locals {
  cloudfront_origin_id = "${var.project_name}-${var.environment}-api"
}

data "aws_cloudfront_cache_policy" "caching_disabled" {
  name = "Managed-CachingDisabled"
}

data "aws_cloudfront_origin_request_policy" "all_viewer_except_host" {
  name = "Managed-AllViewerExceptHostHeader"
}

data "aws_cloudfront_response_headers_policy" "security_headers" {
  name = "Managed-SecurityHeadersPolicy"
}

resource "aws_cloudfront_distribution" "api" {
  enabled         = true
  is_ipv6_enabled = true
  comment         = "${var.project_name}-${var.environment} HTTPS endpoint"
  price_class     = "PriceClass_100"
  http_version    = "http2and3"

  origin {
    domain_name = aws_instance.api.public_dns
    origin_id   = local.cloudfront_origin_id

    custom_origin_config {
      http_port              = 8000
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    target_origin_id       = local.cloudfront_origin_id
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = [
      "DELETE",
      "GET",
      "HEAD",
      "OPTIONS",
      "PATCH",
      "POST",
      "PUT",
    ]

    cached_methods = [
      "GET",
      "HEAD",
    ]

    cache_policy_id            = data.aws_cloudfront_cache_policy.caching_disabled.id
    origin_request_policy_id   = data.aws_cloudfront_origin_request_policy.all_viewer_except_host.id
    response_headers_policy_id = data.aws_cloudfront_response_headers_policy.security_headers.id

    compress = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-api"
  }
}