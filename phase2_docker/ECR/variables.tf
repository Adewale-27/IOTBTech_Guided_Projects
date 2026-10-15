# variables.tf
variable "aws_region" {
  type = string
}

variable "repository_name" {
  type        = string
  description = "ECR repository name"
}

variable "kms_key_arn" {
  type        = string
  description = "Optional customer-managed KMS key ARN. Null uses AES256."
}

variable "max_tagged_images" {
  type = number
}

variable "tags" {
  type = map(string)
}
