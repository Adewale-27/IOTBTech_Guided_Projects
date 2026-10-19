# variables.tf
variable "aws_region" {
  type        = string
  description = "AWS region to create the ECR repository in"
  default     = "eu-west-1"
}

variable "repository_name" {
  type        = string
  description = "ECR repository name"
  default     = "adecloud/zeetafin"
}

variable "kms_key_arn" {
  type        = string
  description = "Optional customer-managed KMS key ARN. Null uses AES256."
  default     = null
}

variable "max_tagged_images" {
  type    = number
  default = 30
}

variable "tags" {
  type = map(string)
  default = {
    ManagedBy   = "terraform"
    Environment = "production"
  }
}
