variable "vpc_id" {
  description = "VPC ID where the resources will be deployed"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID for the EC2 instance"
  type        = string
}

variable "ami_id" {
  description = "Amazon Machine Image (AMI) ID"
  type        = string
}

variable "key_name" {
  description = "The name of the EC2 key pair"
  type        = string
}
