# -------------------------------------- Backend --------------------------------------- #
terraform {
  backend "s3" {
    bucket         = "crc-fbrpinto-terraform-state"
    key            = "frontend/terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "crc-fbrpinto-terraform-lock-frontend"
  }
}

# ------------------------------------- Providers -------------------------------------- #
provider "aws" {
  region = "eu-west-1"
}

provider "aws" {
  region = "us-east-1"
  alias  = "us-east-1"
}

# ------------------------------------- S3 Bucket -------------------------------------- #
# Create an S3 bucket
resource "aws_s3_bucket" "website" {
  bucket        = var.s3_bucket_name
  force_destroy = true
}

# Configure static website hosting for the S3 bucket
resource "aws_s3_bucket_website_configuration" "static_website" {
  bucket = aws_s3_bucket.website.id
  index_document {
    suffix = "index.html"
  }
}

# Configure public access block settings for the S3 bucket
resource "aws_s3_bucket_public_access_block" "public_access_block" {
  bucket                  = aws_s3_bucket.website.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# Attach a policy that specifies the access to the S3 bucket
resource "aws_s3_bucket_policy" "public_access_policy" {
  depends_on = [ aws_s3_bucket_public_access_block.public_access_block ]

  bucket = aws_s3_bucket.website.id
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "PublicReadGetObject",
        "Effect" : "Allow",
        "Principal" : "*",
        "Action" : [
          "s3:GetObject"
        ],
        "Resource" : [
          "${aws_s3_bucket.website.arn}/*"
        ]
      }
    ]
  })
}

# Uploads the Website fronend code to the s3 bucket
resource "null_resource" "remove_and_upload_to_s3" {
  provisioner "local-exec" {
    command = "aws s3 sync ${path.module}/../../frontend/public/ s3://${aws_s3_bucket.website.id}"
  }
}


# ------------------------------------- CloudFront ------------------------------------- #
# Create a certificate for the custom domain name
resource "aws_acm_certificate" "certificate" {
  provider    = aws.us-east-1
  domain_name = var.domain_name
  subject_alternative_names = [
    "www.${var.domain_name}"
  ]
  validation_method = "DNS"
}

# Create the CNAME records for each domain name
resource "aws_route53_record" "cname" {
  for_each = {
    for dvo in aws_acm_certificate.certificate.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = false
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 300
  type            = each.value.type
  zone_id         = var.hosted_zone_id
}


# Validate the created certificate
resource "aws_acm_certificate_validation" "validation" {
  provider        = aws.us-east-1
  certificate_arn = aws_acm_certificate.certificate.arn
}

# Create a record (root) for the domain name
resource "aws_route53_record" "root" {
  name    = aws_acm_certificate.certificate.domain_name
  type    = "A"
  zone_id = var.hosted_zone_id

  alias {
    name                   = aws_cloudfront_distribution.s3_dist.domain_name
    zone_id                = aws_cloudfront_distribution.s3_dist.hosted_zone_id
    evaluate_target_health = false
  }
}

# Create a record (www) for the domain name
resource "aws_route53_record" "www" {
  name    = "www.${aws_acm_certificate.certificate.domain_name}"
  type    = "A"
  zone_id = var.hosted_zone_id

  alias {
    name                   = aws_cloudfront_distribution.s3_dist.domain_name
    zone_id                = aws_cloudfront_distribution.s3_dist.hosted_zone_id
    evaluate_target_health = false
  }
}

#Create a CloudFront distribution
resource "aws_cloudfront_distribution" "s3_dist" {
  depends_on = [aws_acm_certificate_validation.validation]

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = aws_s3_bucket.website.bucket_regional_domain_name
    viewer_protocol_policy = "redirect-to-https"

    cache_policy_id = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"

    compress = true
  }

  enabled = true

  origin {
    domain_name = aws_s3_bucket_website_configuration.static_website.website_endpoint
    origin_id   = aws_s3_bucket.website.bucket_regional_domain_name

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
    acm_certificate_arn            = aws_acm_certificate.certificate.arn
    cloudfront_default_certificate = false
    ssl_support_method             = "sni-only"
    minimum_protocol_version       = "TLSv1.2_2021"
  }

  aliases = [aws_acm_certificate.certificate.domain_name, "www.${aws_acm_certificate.certificate.domain_name}"]
}