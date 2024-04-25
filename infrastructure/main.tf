provider "aws" {
  region = var.aws_region
}

provider "aws" {
  region = "us-east-1"
  alias  = "us-east-1"
}

# Create S3
resource "aws_s3_bucket" "s3_bucket" {
  bucket = var.bucket_name
}

resource "aws_s3_bucket_website_configuration" "s3_static_website" {
  bucket = aws_s3_bucket.s3_bucket.id
  index_document {
    suffix = "index.html"
  }
}

resource "aws_s3_bucket_public_access_block" "public_access_block" {
  bucket                  = aws_s3_bucket.s3_bucket.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "public_access_policy" {
  bucket = aws_s3_bucket.s3_bucket.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = "*",
        Action    = "s3:GetObject",
        Resource  = "${aws_s3_bucket.s3_bucket.arn}/*",
      }
    ]
  })
}


// CloudFront

resource "aws_cloudfront_distribution" "s3_distribution" {
  default_cache_behavior {
    //required
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = aws_s3_bucket.s3_bucket.bucket_regional_domain_name
    viewer_protocol_policy = "redirect-to-https"

    cache_policy_id = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"

    compress = true
  }

  enabled = true

  origin {
    domain_name = aws_s3_bucket_website_configuration.s3_static_website.website_endpoint
    origin_id   = aws_s3_bucket.s3_bucket.bucket_regional_domain_name

    custom_origin_config {
      http_port              = 80
      https_port             = 80
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }


  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
      locations        = []
    }
  }

  viewer_certificate {
    acm_certificate_arn            = var.certificate_arn
    cloudfront_default_certificate = false
    ssl_support_method             = "sni-only"
    minimum_protocol_version       = "TLSv1.2_2021"
  }

  aliases = ["fbrpinto.com", "www.fbrpinto.com"]
}


// Route 53
resource "aws_route53_record" "www" {
  zone_id = var.hosted_zone_id
  name    = "www.fbrpinto.com"
  type    = "A"
  alias {
    name                   = aws_cloudfront_distribution.s3_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.s3_distribution.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "root" {
  zone_id = var.hosted_zone_id
  name    = "fbrpinto.com"
  type    = "A"
  alias {
    name                   = aws_cloudfront_distribution.s3_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.s3_distribution.hosted_zone_id
    evaluate_target_health = false
  }
}





