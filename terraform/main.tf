terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.7"
    }
  }
  required_version = ">= 1.0.0"
}

provider "aws" {
  profile = "temporary"
  region = "ap-southeast-1"
}