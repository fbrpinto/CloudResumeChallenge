# -------------------------------------- Backend --------------------------------------- #
terraform {
  backend "s3" {
    bucket         = "crc-fbrpinto-terraform-state"
    key            = "frontend/terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "crc-fbrpinto-terraform-lock-frontend"
  }

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5"
    }
  }
}

# ------------------------------------- Providers -------------------------------------- #
provider "aws" {
  region = "eu-west-1"
}

# Reads the API token from the CLOUDFLARE_API_TOKEN environment variable
provider "cloudflare" {}

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
  depends_on = [aws_s3_bucket_public_access_block.public_access_block]

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

locals {
  content_types = {
    ".html" : "text/html",
    ".css" : "text/css",
    ".js" : "text/javascript"
    ".svg" : "image/svg+xml"
  }
}

# Uploads the Website fronend code to the s3 bucket
resource "aws_s3_object" "frontend_files" {
  for_each = fileset("${path.module}/../../frontend/public", "**/*")

  bucket       = aws_s3_bucket.website.bucket
  key          = each.key
  source       = "${path.module}/../../frontend/public/${each.key}"
  content_type = lookup(local.content_types, regex("\\.[^.]+$", each.value), null)
  etag         = filemd5("${path.module}/../../frontend/public/${each.key}")
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

# Validate the created certificate
resource "aws_acm_certificate_validation" "validation" {
  provider        = aws.us-east-1
  certificate_arn = aws_acm_certificate.certificate.arn
}

# --------------------------------- Cloudflare DNS ------------------------------------- #
# Certificate validation records, needed for ACM to renew the certificate
resource "cloudflare_dns_record" "cname" {
  for_each = {
    for dvo in aws_acm_certificate.certificate.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id = var.cloudflare_zone_id
  name    = trimsuffix(each.value.name, ".")
  content = trimsuffix(each.value.record, ".")
  type    = each.value.type
  ttl     = 1
  proxied = false
}

# Root record, CNAME (flattened by Cloudflare) to the CloudFront distribution
resource "cloudflare_dns_record" "root" {
  zone_id = var.cloudflare_zone_id
  name    = var.domain_name
  content = aws_cloudfront_distribution.s3_dist.domain_name
  type    = "CNAME"
  ttl     = 1
  proxied = false
}

# www record, CNAME to the CloudFront distribution
resource "cloudflare_dns_record" "www" {
  zone_id = var.cloudflare_zone_id
  name    = "www.${var.domain_name}"
  content = aws_cloudfront_distribution.s3_dist.domain_name
  type    = "CNAME"
  ttl     = 1
  proxied = false
}

# The domain sends no email: SPF allows no senders, DMARC tells receivers to reject spoofed mail
resource "cloudflare_dns_record" "spf" {
  zone_id = var.cloudflare_zone_id
  name    = var.domain_name
  content = "\"v=spf1 -all\""
  type    = "TXT"
  ttl     = 1
}

resource "cloudflare_dns_record" "dmarc" {
  zone_id = var.cloudflare_zone_id
  name    = "_dmarc.${var.domain_name}"
  content = "\"v=DMARC1; p=reject;\""
  type    = "TXT"
  ttl     = 1
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

# -------------------------------------------------------------------------------------- #
# ------------------------------------- Monitoring ------------------------------------- #
# -------------------------------------------------------------------------------------- #

# Keeping this free: every alarm lists its metric directly (no metric math) and uses a period
# of 60 s or more. Alarms under 60 s are high resolution and are billed from the first one.

# The alerts topic and the API are created by the backend stack, which CI applies first
data "aws_sns_topic" "alerts_us_east_1" {
  provider = aws.us-east-1
  name     = var.sns_topic_us_east_1_name
}

data "aws_apigatewayv2_apis" "api" {
  name          = var.apigw_name
  protocol_type = "HTTP"
}

locals {
  cloudfront_dimensions = {
    DistributionId = aws_cloudfront_distribution.s3_dist.id
    Region         = "Global"
  }
}

# ---------------------------------- CloudWatch Alarms --------------------------------- #
# The description is the label sent to ntfy, so keep it short and free of names
# CloudFront metrics only exist in us-east-1

# Normal peak is about 1,000 requests per 5 minutes
resource "aws_cloudwatch_metric_alarm" "cloudfront_requests" {
  provider            = aws.us-east-1
  alarm_name          = "crc-fbrpinto-cloudfront-requests"
  alarm_description   = "Site requests per 5 min"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Requests"
  namespace           = "AWS/CloudFront"
  period              = 300
  statistic           = "Sum"
  threshold           = 5000
  treat_missing_data  = "notBreaching"
  dimensions          = local.cloudfront_dimensions

  alarm_actions = [data.aws_sns_topic.alerts_us_east_1.arn]
  ok_actions    = [data.aws_sns_topic.alerts_us_east_1.arn]
}

# Data transfer is what CloudFront bills for; normal peak is a few MB per hour
resource "aws_cloudwatch_metric_alarm" "cloudfront_bytes" {
  provider            = aws.us-east-1
  alarm_name          = "crc-fbrpinto-cloudfront-bytes"
  alarm_description   = "Site bytes downloaded per hour"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "BytesDownloaded"
  namespace           = "AWS/CloudFront"
  period              = 3600
  statistic           = "Sum"
  threshold           = 1000000000
  treat_missing_data  = "notBreaching"
  dimensions          = local.cloudfront_dimensions

  alarm_actions = [data.aws_sns_topic.alerts_us_east_1.arn]
  ok_actions    = [data.aws_sns_topic.alerts_us_east_1.arn]
}


# ------------------------------------- Dashboard -------------------------------------- #
# Free (up to 3 dashboards), as long as it is only viewed in the console
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "crc-fbrpinto"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric", x = 0, y = 0, width = 12, height = 6
        properties = {
          title  = "Counter Lambda"
          region = "eu-west-1"
          stat   = "Sum"
          period = 300
          metrics = [
            ["AWS/Lambda", "Invocations", "FunctionName", var.backend_lambda_function_name],
            ["AWS/Lambda", "Errors", "FunctionName", var.backend_lambda_function_name],
          ]
        }
      },
      {
        type = "metric", x = 12, y = 0, width = 12, height = 6
        properties = {
          title  = "Counter Lambda duration (ms)"
          region = "eu-west-1"
          period = 300
          metrics = [
            ["AWS/Lambda", "Duration", "FunctionName", var.backend_lambda_function_name, { stat = "Average" }],
            ["AWS/Lambda", "Duration", "FunctionName", var.backend_lambda_function_name, { stat = "Maximum" }],
          ]
        }
      },
      {
        type = "metric", x = 0, y = 6, width = 12, height = 6
        properties = {
          title  = "API requests (4xx includes throttled 429s)"
          region = "eu-west-1"
          stat   = "Sum"
          period = 300
          metrics = [
            ["AWS/ApiGateway", "Count", "ApiId", one(data.aws_apigatewayv2_apis.api.ids), "Stage", "dev"],
            ["AWS/ApiGateway", "4xx", "ApiId", one(data.aws_apigatewayv2_apis.api.ids), "Stage", "dev"],
            ["AWS/ApiGateway", "5xx", "ApiId", one(data.aws_apigatewayv2_apis.api.ids), "Stage", "dev"],
          ]
          annotations = { horizontal = [{ label = "Alarm", value = 1000 }] }
        }
      },
      {
        type = "metric", x = 12, y = 6, width = 12, height = 6
        properties = {
          title  = "Site requests"
          region = "us-east-1"
          stat   = "Sum"
          period = 300
          metrics = [
            ["AWS/CloudFront", "Requests", "DistributionId", aws_cloudfront_distribution.s3_dist.id, "Region", "Global"],
          ]
          annotations = { horizontal = [{ label = "Alarm", value = 5000 }] }
        }
      },
      {
        type = "metric", x = 0, y = 12, width = 12, height = 6
        properties = {
          title  = "Site bytes downloaded per hour"
          region = "us-east-1"
          stat   = "Sum"
          period = 3600
          metrics = [
            ["AWS/CloudFront", "BytesDownloaded", "DistributionId", aws_cloudfront_distribution.s3_dist.id, "Region", "Global"],
          ]
          annotations = { horizontal = [{ label = "Alarm", value = 1000000000 }] }
        }
      },
      {
        type = "metric", x = 12, y = 12, width = 12, height = 6
        properties = {
          title  = "Estimated bill this month (USD)"
          region = "us-east-1"
          stat   = "Maximum"
          period = 21600
          metrics = [
            ["AWS/Billing", "EstimatedCharges", "Currency", "USD"],
          ]
          annotations = { horizontal = [{ label = "Alarm", value = 5 }] }
        }
      },
    ]
  })
}
