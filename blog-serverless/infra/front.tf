terraform {
}

# --- S3 para o front ---
resource "random_id" "suffix" {
  byte_length = 4
}

# Pega o domínio do API Gateway sem "https://"
locals {
  api_domain = replace(aws_apigatewayv2_api.api.api_endpoint, "https://", "")
}

# Policies gerenciadas (evitar digitar IDs)
data "aws_cloudfront_cache_policy" "disabled" {
  name = "Managed-CachingDisabled"
}
data "aws_cloudfront_origin_request_policy" "allviewer_no_host" {
  name = "Managed-AllViewerExceptHostHeader"
}

resource "aws_s3_bucket" "front" {
  bucket        = "meu-blog-front-${random_id.suffix.hex}"
  force_destroy = true
}

resource "aws_s3_bucket_ownership_controls" "front" {
  bucket = aws_s3_bucket.front.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "front" {
  bucket                  = aws_s3_bucket.front.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# --- CloudFront OAC (para acessar S3 privado) ---
resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "front-oac"
  description                       = "OAC para front"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# --- CloudFront Distribution ---
resource "aws_cloudfront_distribution" "cdn" {
  enabled             = true
  default_root_object = "index.html"

  origin {
    domain_name              = aws_s3_bucket.front.bucket_regional_domain_name
    origin_id                = "s3-front"
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
  }

  default_cache_behavior {
    target_origin_id       = "s3-front"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD", "OPTIONS"]
    compress               = true

    forwarded_values {
      query_string = true
      headers      = ["Origin"]

      cookies {
        forward = "none"
      }
    }
  }


  # SPA-friendly: 403/404 -> index.html (opcional)
  custom_error_response {
    error_code         = 403
    response_code      = 200
    response_page_path = "/index.html"
  }
  custom_error_response {
    error_code         = 404
    response_code      = 200
    response_page_path = "/index.html"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  origin {
    domain_name = local.api_domain # ex.: tcr0w2el0l.execute-api.sa-east-1.amazonaws.com
    origin_id   = "api-gw-origin"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  # Behavior para /api/* apontando para o API Gateway
  ordered_cache_behavior {
    path_pattern     = "/api/*"
    target_origin_id = "api-gw-origin"

    allowed_methods = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods  = ["GET", "HEAD", "OPTIONS"]

    cache_policy_id          = data.aws_cloudfront_cache_policy.disabled.id
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.allviewer_no_host.id

    viewer_protocol_policy = "redirect-to-https"
    compress               = true
  }

  # Associe o WAF NA DISTRIBUIÇÃO
  web_acl_id = aws_wafv2_web_acl.cf_acl.arn

}

# --- Permissão para CloudFront ler do S3 (amarrado ao ARN da distribuição) ---
data "aws_iam_policy_document" "s3_cf_read" {
  statement {
    sid     = "AllowCloudFrontRead"
    effect  = "Allow"
    actions = ["s3:GetObject"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    resources = ["${aws_s3_bucket.front.arn}/*"]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.cdn.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "front" {
  bucket = aws_s3_bucket.front.id
  policy = data.aws_iam_policy_document.s3_cf_read.json
}

output "front_bucket" {
  value = aws_s3_bucket.front.bucket
}

output "cloudfront_domain" {
  value = aws_cloudfront_distribution.cdn.domain_name
}
