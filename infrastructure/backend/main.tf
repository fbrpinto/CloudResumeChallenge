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

# Create Backend Lambda function
resource "aws_lambda_function" "backend_lambda" {
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

# ------------------------------------- SNS Topic -------------------------------------- #
# Create an SNS Topic
resource "aws_sns_topic" "sns_topic" {
  name = var.sns_topic_name
}


# --------------------------------- CloudWatch Metric ---------------------------------- #
# Define a metric (Backend Lambda function invocation) to watch
resource "aws_cloudwatch_metric_alarm" "cloud_watch_alarm" {
  alarm_name          = var.cloud_watch_metric_name
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  datapoints_to_alarm = 1
  metric_name         = "Invocations"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "SampleCount"
  threshold           = 15000

  dimensions = {
    FunctionName = aws_lambda_function.backend_lambda.function_name
  }

  alarm_description = "Alarm when Lambda function has too many invocations"
  alarm_actions     = [aws_sns_topic.sns_topic.arn]
  ok_actions        = [aws_sns_topic.sns_topic.arn]
}

# Subscribe an email address to the SNS topic
resource "aws_sns_topic_subscription" "email_subscription" {
  topic_arn = aws_sns_topic.sns_topic.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

# Subscribe PagerDuty webhook URL to the SNS topic (disabled: PagerDuty no longer used)
# resource "aws_sns_topic_subscription" "pagerduty_subscription" {
#   topic_arn = aws_sns_topic.sns_topic.arn
#   protocol  = "https"
#   endpoint  = var.pagerduty_webhook
# }

# Subscribe Lambda Function (to integrate with Slack) to the SNS topic
resource "aws_sns_topic_subscription" "lambda_subscription" {
  topic_arn = aws_sns_topic.sns_topic.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.slack_lambda.arn
}

# ------------------------ Lambda function (Slack Integration) ------------------------- #
# Add the lambda function code to a .zip file
data "archive_file" "lambda_function_slack_zip" {
  type        = "zip"
  output_path = "${path.module}/lambda_functions/lambda_function_slack.zip"
  source_file = "${path.module}/lambda_functions/slack/lambda_function.py"
}

# Define IAM role for Lambda function
resource "aws_iam_role" "lambda_slack_role" {
  name = "lambda-slack-role"

  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [{
      "Effect" : "Allow",
      "Principal" : { "Service" : "lambda.amazonaws.com" },
      "Action" : "sts:AssumeRole"
    }]
  })
}

# Create Lambda function
resource "aws_lambda_function" "slack_lambda" {
  filename      = data.archive_file.lambda_function_slack_zip.output_path
  function_name = var.slack_lambda_function_name
  role          = aws_iam_role.lambda_slack_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.14"

  environment {
    variables = {
      SLACK_WEBHOOK = var.slack_webhook
    }
  }
}

# Allow SNS to invoke Lambda function
resource "aws_lambda_permission" "allow_sns_to_invoke_lambda" {
  statement_id  = "AllowSNSInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.slack_lambda.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.sns_topic.arn
}
