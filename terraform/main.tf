provider "aws" {
  region = "us-east-1"
}

resource "aws_security_group" "laravel_sg" {
  name        = "laravel-vue-sg"
  description = "Security group for the Laravel-Vue application"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Allow SSH access from anywhere
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Allow HTTP traffic from anywhere
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Allow HTTPS traffic from anywhere
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]  # Allow all outbound traffic
  }
}

resource "aws_iam_role" "ec2_role" {
  name = "ec2_role_for_docker"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Effect    = "Allow"
        Sid       = ""
      },
    ]
  })
}

resource "aws_iam_role_policy" "ec2_role_policy" {
  name   = "ec2_role_policy"
  role   = aws_iam_role.ec2_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = "ecr:GetAuthorizationToken"
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action   = "ecr:BatchGetImage"
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action   = "ecr:BatchGetManifest"
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_instance_profile" "ec2_role" {
  name = "ec2_instance_profile"
  role = aws_iam_role.ec2_role.name
}

resource "aws_instance" "laravel_app" {
  ami           = var.ami_id
  instance_type = "t4g.nano"  # Cheapest instance
  key_name      = var.key_name
  vpc_security_group_ids = [aws_security_group.laravel_sg.id]

  user_data = <<-EOF
              #!/bin/bash
              # Install Docker and start the service
              yum update -y
              yum install -y docker
              service docker start
              usermod -a -G docker ec2-user
              # Pull and run the Docker container from ECR
              aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <aws-account-id>.dkr.ecr.us-east-1.amazonaws.com
              docker pull <aws-account-id>.dkr.ecr.us-east-1.amazonaws.com/laravel-vue-app:latest
              docker run -d -p 80:80 -p 9000:9000 <aws-account-id>.dkr.ecr.us-east-1.amazonaws.com/laravel-vue-app:latest
              EOF

  tags = {
    Name = "Laravel-Vue-Server"
  }

  associate_public_ip_address = true
  iam_instance_profile = aws_iam_instance_profile.ec2_role.name
}
