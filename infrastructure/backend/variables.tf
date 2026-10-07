variable "ntfy_topic" {
  description = "ntfy.sh topic for alert push notifications (anyone with the name can read it)"
  sensitive   = true
}

variable "notification_email" {
  description = "E-mail to send notification based on CloudWatch metrics"
}

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID to add the records"
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

variable "sns_topic_us_east_1_name" {
  description = "Name of the SNS topic for us-east-1 alarms and cost anomalies (also used by the frontend and account stacks)"
  default     = "crc-fbrpinto-sns-us-east-1-tf"
}

variable "cloud_watch_metric_name" {
  description = "CloudWatch metric name to monitor the backend Lambda function"
  default     = "crc-fbrpinto-lambda-tf"
}

variable "notify_lambda_function_name" {
  description = "Lambda function name that sends alerts to ntfy"
  default     = "crc-fbrpinto-lambda_notify-tf"
}

variable "anomaly_threshold" {
  description = "Cost anomaly threshold in USD, shown in ntfy messages. Keep in sync with the account stack"
  default     = 5
}

variable "log_retention_days" {
  description = "Days to keep Lambda logs"
  default     = 14
}
