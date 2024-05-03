variable "hosted_zone_id" {
  description = "Hosted Zone ID to add the records"
}

variable "domain_name" {
  description = "Static website domain name"
  
}
variable "s3_bucket_name" {
  description = "The name of the S3 bucket for static website hosting"
  default = "crc-fbrpinto-s3-tf"
}
