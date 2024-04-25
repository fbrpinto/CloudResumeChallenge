variable "aws_region" {
  description = "The AWS region where resources will be provisioned"
  default     = "us-east-1"
}

variable "bucket_name" {
  description = "The name of the S3 bucket for static website hosting"
}

variable "certificate_arn" {
  description = "Acquirer Reference Number of the certificate"
}

variable "hosted_zone_id" {
  description = "Hosted Zone ID to add the records"
}
