variable "notification_email" {
  description = "E-mail for budget and cost anomaly alerts (set in a local, git-ignored terraform.tfvars)"
  type        = string
}

variable "sns_topic_name" {
  description = "us-east-1 SNS topic created by the backend stack"
  default     = "crc-fbrpinto-sns-us-east-1-tf"
}

variable "daily_budget" {
  description = "Daily spend in USD that triggers an email"
  default     = "1"
}

variable "anomaly_threshold" {
  description = "Cost anomaly impact in USD that triggers an alert. Keep in sync with the backend stack"
  default     = 5
}

variable "billing_alarm_threshold" {
  description = "Month-to-date estimated bill in USD that triggers the alarm"
  default     = 5
}
