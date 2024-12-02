variable "ami_id" {
  description = "AMI ID for the EC2 instance"
  type        = string
}

variable "key_name" {
  description = "Key pair for SSH access to the EC2 instance"
  type        = string
}
