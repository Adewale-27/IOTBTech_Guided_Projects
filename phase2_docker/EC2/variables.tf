variable "aws_region" {
  description = "AWS region"
  type        = string

}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string

}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet"
  type        = string
}

variable "allowed_ssh_cidr" {
  description = "CIDR block allowed for SSH access"
  type        = string

}

variable "instance_type" {
  description = "Instance type"
  type        = string

}

variable "key_pair" {
  description = "Key pair"
  type        = string

}
