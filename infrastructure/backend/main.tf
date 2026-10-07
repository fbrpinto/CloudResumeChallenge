# -------------------------------------- Backend --------------------------------------- #
terraform {
  backend "s3" {
    bucket         = "crc-fbrpinto-terraform-state"
    key            = "backend/terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "crc-fbrpinto-terraform-lock-backend"
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

# CloudFront and billing metrics, and cost anomaly alerts, only exist in us-east-1
provider "aws" {
  region = "us-east-1"
  alias  = "us-east-1"
}

# Reads the API token from the CLOUDFLARE_API_TOKEN environment variable
provider "cloudflare" {}


# ----------------------------------- DynamoDB Table ----------------------------------- #
# Create DynamoDB table
resource "aws_dynamodb_table" "visitors" {
  name         = var.dynamodb_table_name
  hash_key     = "id"
  billing_mode = "PAY_PER_REQUEST"

  attribute {
    name = "id"
    type = "S"
  }
}


# ----------------------------------- Lambda Function ---------------------------------- #
# Add the lambda function code to a .zip file
data "archive_file" "lambda_function_zip" {
  type        = "zip"
  output_path = "${path.module}/lambda_functions/lambda_function_backend.zip"
  source_file = "${path.module}/../../backend/lambda_function.py"
}

# Define IAM role for Lambda function
resource "aws_iam_role" "lambda_role" {
  name = "lambda_role"

  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [{
      "Effect" : "Allow",
      "Principal" : { "Service" : "lambda.amazonaws.com" },
      "Action" : "sts:AssumeRole"
    }]
  })
}

# Attach policy to IAM role (non-exclusive: other roles may use the same policy)
resource "aws_iam_role_policy_attachment" "lambda_execution" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}

# Hand the existing attachment over from the old exclusive resource without detaching it
removed {
  from = aws_iam_policy_attachment.lambda_execution

  lifecycle {
    destroy = false
  }
}

import {
  to = aws_iam_role_policy_attachment.lambda_execution
  id = "lambda_role/arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}

# Let the function write logs (only Lambda's START/END/REPORT lines and errors: the code doesn't print)
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Created by Lambda in 2024 with no retention
import {
  to = aws_cloudwatch_log_group.backend_lambda
  id = "/aws/lambda/${var.backend_lambda_function_name}"
}

resource "aws_cloudwatch_log_group" "backend_lambda" {
  name              = "/aws/lambda/${var.backend_lambda_function_name}"
  retention_in_days = var.log_retention_days
}

# Create Backend Lambda function
resource "aws_lambda_function" "backend_lambda" {
  depends_on = [aws_cloudwatch_log_group.backend_lambda]

  filename      = data.archive_file.lambda_function_zip.output_path
  function_name = var.backend_lambda_function_name
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.13"

  # More memory also means more CPU, so cold starts finish well within the timeout
  memory_size = 512
  timeout     = 10
}

# Allow API Gateway to invoke Lambda function
resource "aws_lambda_permission" "apigw_permission" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.backend_lambda.function_name
  principal     = "apigateway.amazonaws.com"
}


# ------------------------------------- API Gateway ------------------------------------ #
# Create API Gateway API
resource "aws_apigatewayv2_api" "apigw" {
  name          = var.apigw_name
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
    allow_headers = ["*"]
  }
}

# Define API Gateway Integration with Lambda function
resource "aws_apigatewayv2_integration" "lambda" {
  api_id             = aws_apigatewayv2_api.apigw.id
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
  integration_uri    = aws_lambda_function.backend_lambda.invoke_arn
}

# Define API Gateway route
resource "aws_apigatewayv2_route" "visitors" {
  api_id    = aws_apigatewayv2_api.apigw.id
  route_key = "POST /visitors"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

# Create a certificate for the custom domain name
resource "aws_acm_certificate" "api_certificate" {
  domain_name       = var.api_domain
  validation_method = "DNS"
}

# Validate the certificate for the custom domain name
resource "aws_acm_certificate_validation" "api_validation" {
  certificate_arn = aws_acm_certificate.api_certificate.arn
}

# Certificate validation record in Cloudflare, needed for ACM to renew the certificate
resource "cloudflare_dns_record" "cname" {
  for_each = {
    for dvo in aws_acm_certificate.api_certificate.domain_validation_options : dvo.domain_name => {
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

# Create a record in Cloudflare for the custom domain
resource "cloudflare_dns_record" "api_record" {
  zone_id = var.cloudflare_zone_id
  name    = aws_acm_certificate.api_certificate.domain_name
  content = aws_apigatewayv2_domain_name.domain.domain_name_configuration[0].target_domain_name
  type    = "CNAME"
  ttl     = 1
  proxied = false
}

# Set the custom domain name
resource "aws_apigatewayv2_domain_name" "domain" {
  depends_on  = [aws_acm_certificate_validation.api_validation]
  domain_name = aws_acm_certificate.api_certificate.domain_name
  domain_name_configuration {
    certificate_arn = aws_acm_certificate.api_certificate.arn
    endpoint_type   = "REGIONAL"
    security_policy = "TLS_1_2"
  }
}

# Map the custom domain to the API
resource "aws_apigatewayv2_api_mapping" "mapping" {
  domain_name = aws_apigatewayv2_domain_name.domain.id
  api_id      = aws_apigatewayv2_api.apigw.id
  stage       = aws_apigatewayv2_stage.stage.name
}

# Deploy API Gateway
resource "aws_apigatewayv2_stage" "stage" {
  api_id      = aws_apigatewayv2_api.apigw.id
  name        = "dev"
  auto_deploy = true

  # Cap the request rate so a flood can't run up the bill (throttled requests aren't billed)
  default_route_settings {
    throttling_rate_limit  = 10
    throttling_burst_limit = 20
  }
}


# -------------------------------------------------------------------------------------- #
# ------------------------------------- Monitoring ------------------------------------- #
# -------------------------------------------------------------------------------------- #

# Keeping this free: every alarm lists its metric directly (no metric math) and uses a period
# of 60 s or more. Alarms under 60 s are high resolution and are billed from the first one.
# The free tier covers 10 standard alarms per account; this repo uses 5.

# ------------------------------------- SNS Topics ------------------------------------- #
# Alerts for metrics in eu-west-1 (Lambda, API Gateway)
resource "aws_sns_topic" "sns_topic" {
  name = var.sns_topic_name
}

# Alerts for metrics that only exist in us-east-1 (CloudFront, billing) and for cost anomalies
resource "aws_sns_topic" "alerts_us_east_1" {
  provider = aws.us-east-1
  name     = var.sns_topic_us_east_1_name
}

# CloudWatch alarms and Cost Anomaly Detection may publish to the us-east-1 topic
data "aws_iam_policy_document" "alerts_us_east_1" {
  statement {
    sid       = "AccountOwner"
    actions   = ["SNS:Publish", "SNS:Subscribe", "SNS:GetTopicAttributes", "SNS:SetTopicAttributes"]
    resources = [aws_sns_topic.alerts_us_east_1.arn]

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceOwner"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }

  statement {
    sid       = "AlertServices"
    actions   = ["SNS:Publish"]
    resources = [aws_sns_topic.alerts_us_east_1.arn]

    principals {
      type        = "Service"
      identifiers = ["cloudwatch.amazonaws.com", "costalerts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_sns_topic_policy" "alerts_us_east_1" {
  provider = aws.us-east-1
  arn      = aws_sns_topic.alerts_us_east_1.arn
  policy   = data.aws_iam_policy_document.alerts_us_east_1.json
}

data "aws_caller_identity" "current" {}

# Email and ntfy receive every alert from both topics
resource "aws_sns_topic_subscription" "email_subscription" {
  topic_arn = aws_sns_topic.sns_topic.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

resource "aws_sns_topic_subscription" "email_subscription_us_east_1" {
  provider  = aws.us-east-1
  topic_arn = aws_sns_topic.alerts_us_east_1.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

resource "aws_sns_topic_subscription" "notify_subscription" {
  topic_arn = aws_sns_topic.sns_topic.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.notify_lambda.arn
}

resource "aws_sns_topic_subscription" "notify_subscription_us_east_1" {
  provider  = aws.us-east-1
  topic_arn = aws_sns_topic.alerts_us_east_1.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.notify_lambda.arn
}


# ---------------------------------- CloudWatch Alarms --------------------------------- #
# The description is the label sent to ntfy, so keep it short and free of names
resource "aws_cloudwatch_metric_alarm" "cloud_watch_alarm" {
  alarm_name          = var.cloud_watch_metric_name
  alarm_description   = "Counter Lambda calls per minute"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  datapoints_to_alarm = 1
  metric_name         = "Invocations"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "SampleCount"
  threshold           = 15000
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.backend_lambda.function_name
  }

  alarm_actions = [aws_sns_topic.sns_topic.arn]
  ok_actions    = [aws_sns_topic.sns_topic.arn]
}

# Normal peak is a few hundred requests per 5 minutes
resource "aws_cloudwatch_metric_alarm" "api_requests" {
  alarm_name          = "crc-fbrpinto-api-requests"
  alarm_description   = "API requests per 5 min"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Count"
  namespace           = "AWS/ApiGateway"
  period              = 300
  statistic           = "Sum"
  threshold           = 1000
  treat_missing_data  = "notBreaching"

  dimensions = {
    ApiId = aws_apigatewayv2_api.apigw.id
    Stage = aws_apigatewayv2_stage.stage.name
  }

  alarm_actions = [aws_sns_topic.sns_topic.arn]
  ok_actions    = [aws_sns_topic.sns_topic.arn]
}


# ------------------------- Lambda function (ntfy notifications) ------------------------ #
# Add the lambda function code to a .zip file
data "archive_file" "lambda_function_notify_zip" {
  type        = "zip"
  output_path = "${path.module}/lambda_functions/lambda_function_notify.zip"
  source_file = "${path.module}/lambda_functions/notify/lambda_function.py"
}

# Define IAM role for Lambda function
resource "aws_iam_role" "lambda_notify_role" {
  name = "lambda-notify-role"

  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [{
      "Effect" : "Allow",
      "Principal" : { "Service" : "lambda.amazonaws.com" },
      "Action" : "sts:AssumeRole"
    }]
  })
}

# Let the function write logs, so failed deliveries are visible
resource "aws_iam_role_policy_attachment" "lambda_notify_logs" {
  role       = aws_iam_role.lambda_notify_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_cloudwatch_log_group" "lambda_notify" {
  name              = "/aws/lambda/${var.notify_lambda_function_name}"
  retention_in_days = var.log_retention_days
}

# Create Lambda function
resource "aws_lambda_function" "notify_lambda" {
  depends_on = [aws_cloudwatch_log_group.lambda_notify]

  filename         = data.archive_file.lambda_function_notify_zip.output_path
  source_code_hash = data.archive_file.lambda_function_notify_zip.output_base64sha256
  function_name    = var.notify_lambda_function_name
  role             = aws_iam_role.lambda_notify_role.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.14"
  timeout          = 15

  environment {
    variables = {
      NTFY_TOPIC        = var.ntfy_topic
      ANOMALY_THRESHOLD = var.anomaly_threshold
    }
  }
}

# Allow both SNS topics to invoke Lambda function
resource "aws_lambda_permission" "allow_sns_to_invoke_lambda" {
  statement_id  = "AllowSNSInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.notify_lambda.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.sns_topic.arn
}

resource "aws_lambda_permission" "allow_sns_us_east_1_to_invoke_lambda" {
  statement_id  = "AllowSNSInvokeUsEast1"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.notify_lambda.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.alerts_us_east_1.arn
}
