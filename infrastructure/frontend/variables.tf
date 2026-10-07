variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID to add the records"
}

variable "domain_name" {
  description = "Static website domain name"

}
variable "s3_bucket_name" {
  description = "The name of the S3 bucket for static website hosting"
  default     = "crc-fbrpinto-s3-tf"
}

variable "sns_topic_us_east_1_name" {
  description = "SNS topic for us-east-1 alarms (created by the backend stack)"
  default     = "crc-fbrpinto-sns-us-east-1-tf"
}

variable "apigw_name" {
  description = "API Gateway name (created by the backend stack), shown on the dashboard"
  default     = "crc-fbrpinto-apigw-tf"
}

variable "backend_lambda_function_name" {
  description = "Counter Lambda function name (created by the backend stack), shown on the dashboard"
  default     = "crc-fbrpinto-lambda-tf"
}
