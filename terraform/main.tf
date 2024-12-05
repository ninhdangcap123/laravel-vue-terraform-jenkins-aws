provider "aws" {
  region = "ap-southeast-1"
}

# Get default VPC
data "aws_vpc" "default" {
  default = true
}

# Get default Subnets in the default VPC
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Get the latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "owner-id"
    values = ["137112412989"] # Amazon AMI Owner ID
  }
}

# Security Group
resource "aws_security_group" "ninh_laravel_sg" {
  name        = "ninh_laravel_sg"
  description = "Security group for Laravel-Vue app"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ECR Repository
resource "aws_ecr_repository" "ninh_laravel_vue_repo" {
  name = "ninh_laravel_vue_app"
}

# IAM Role and Profile for EC2
resource "aws_iam_role" "ninh_ec2_role" {
  name = "ninh_ec2_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Effect    = "Allow"
      }
    ]
  })
}

resource "aws_iam_role_policy" "ninh_ec2_policy" {
  name = "ninh_ec2_policy"
  role = aws_iam_role.ninh_ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = ["ecr:GetAuthorizationToken", "ecr:BatchGetImage", "ecr:BatchCheckLayerAvailability", "ecr:PutImage", "ecr:InitiateLayerUpload", "ecr:UploadLayerPart", "ecr:CompleteLayerUpload"]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ninh_ec2_instance_profile" {
  name = "ninh_ec2_instance_profile"
  role = aws_iam_role.ninh_ec2_role.name
}

# EC2 Instance
resource "aws_instance" "ninh_laravel_app" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t2.micro"
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.ninh_laravel_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ninh_ec2_instance_profile.name

  subnet_id = data.aws_subnets.default.ids[0]

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y docker
              service docker start
              usermod -a -G docker ec2-user
              $(aws ecr get-login-password --region ap-southeast-1 | docker login --username AWS --password-stdin ${aws_ecr_repository.ninh_laravel_vue_repo.repository_url})
              docker pull ${aws_ecr_repository.ninh_laravel_vue_repo.repository_url}:latest
              docker run -d -p 80:80 ${aws_ecr_repository.ninh_laravel_vue_repo.repository_url}:latest
              EOF

  tags = {
    Name = "ninh_laravel_app"
  }
}
