variable "slack_webhook" {
  description = "Webhook for Slack Integration"
}

variable "pagerduty_webhook" {
  description = "Webhook for PagerDuty Integration"
}

variable "notification_email" {
  description = "E-mail to send notification based on CloudWatch metrics"
}

variable "hosted_zone_id" {
  description = "Hosted Zone ID to add the records"
}

variable "api_domain" {
  description = "Custom Domain Name for the API (used by frontend code)"
}

variable "dynamodb_table_name" {
  description = "DynamoDB table name"
  default     = "crc-fbrpinto-dynamodb-tf"
}

variable "backend_lambda_function_name" {
  description = "Lambda function name for the Backend Code (integration with DynamoDB and API GW)"
  default     = "crc-fbrpinto-lambda-tf"
}

variable "apigw_name" {
  description = "API Gateway name"
  default     = "crc-fbrpinto-apigw-tf"
}

variable "sns_topic_name" {
  description = "Name of the SNS topic to integrate with CloudWatch"
  default     = "crc-fbrpinto-sns-tf"
}

variable "cloud_watch_metric_name" {
  description = "CloudWatch metric name to monitor the backend Lambda function"
  default     = "crc-fbrpinto-lambda-tf"
}

variable "slack_lambda_function_name" {
  description = "Lambda function name to integrate with Slack to notify when an alarm is triggered"
  default     = "crc-fbrpinto-lambda_slack-tf"
}
