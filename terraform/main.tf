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
  region = "ap-southeast-1"
}

# Create a VPC
resource "aws_vpc" "default" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "ninhnh-vti-vpc"
  }
}

# Retrieve availability zones
data "aws_availability_zones" "available" {}

# Create public subnets
resource "aws_subnet" "public_subnet" {
  count                   = 2
  vpc_id                 = aws_vpc.default.id
  cidr_block             = "10.0.${count.index}.0/24"
  availability_zone      = element(data.aws_availability_zones.available.names, count.index)

  map_public_ip_on_launch = true

  tags = {
    Name = "ninhnh-vti-public-subnet-${count.index}"
  }
}

# Create private subnets for EKS nodes
resource "aws_subnet" "private_subnet" {
  count                   = 2
  vpc_id                 = aws_vpc.default.id
  cidr_block             = "10.0.${count.index + 2}.0/24"  # Adjusting CIDR for private subnets
  availability_zone      = element(data.aws_availability_zones.available.names, count.index)

  tags = {
    Name = "ninhnh-vti-private-subnet-${count.index}"
  }
}

# Create an Internet Gateway
resource "aws_internet_gateway" "default" {
  vpc_id = aws_vpc.default.id

  tags = {
    Name = "ninhnh-vti-internet-gateway"
  }
}

# Create a route table for the public subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.default.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.default.id
  }

  tags = {
    Name = "public_route_table"
  }
}

# Associate the route table with the public subnets
resource "aws_route_table_association" "public_subnet_association" {
  count          = 2
  subnet_id      = aws_subnet.public_subnet[count.index].id
  route_table_id = aws_route_table.public.id
}

# Create an S3 bucket for static website hosting
resource "aws_s3_bucket" "static_site" {
  bucket = "ninhnh-vti-bucket-static-web-123456"

  tags = {
    Name = "ninhnh-vti-static-site-bucket"
  }
}

# Configure S3 bucket for website hosting
resource "aws_s3_bucket_website_configuration" "static_site_config" {
  bucket = aws_s3_bucket.static_site.id

  index_document {
    suffix = "index.html"
  }
}

# Add a bucket policy to allow public access for static website hosting
resource "aws_s3_bucket_policy" "static_site_policy" {
  bucket = aws_s3_bucket.static_site.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.static_site.arn}/*"
      }
    ]
  })
}
# Security group to allow PostgreSQL traffic
resource "aws_security_group" "default" {
  vpc_id = aws_vpc.default.id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "postgres_security_group"
  }
}

# Create a subnet group for RDS
resource "aws_db_subnet_group" "default" {
  name       = "default-subnet-group"
  subnet_ids = aws_subnet.public_subnet[*].id

  tags = {
    Name = "ninhnh-vti-rds-subnet-group"
  }
}

# Define variables for sensitive data
variable "db_username" {
  type        = string
  description = "Username for PostgreSQL database"
  default     = "postgres"
}

variable "db_password" {
  type        = string
  description = "Password for PostgreSQL database"
  default     = "ninhdangcap123"
}

# Store the database username in SSM Parameter Store
resource "aws_ssm_parameter" "db_username" {
  name        = "/ninhnh/db_username"
  description = "Username for PostgreSQL database"
  type        = "SecureString"
  value       = var.db_username
}

# Store the database password in SSM Parameter Store
resource "aws_ssm_parameter" "db_password" {
  name        = "/ninhnh/db_password"
  description = "Password for PostgreSQL database"
  type        = "SecureString"
  value       = var.db_password
}

# Data source to retrieve the SSM parameter for the database username
data "aws_ssm_parameter" "db_username" {
  name = aws_ssm_parameter.db_username.name
}

# Data source to retrieve the SSM parameter for the database password
data "aws_ssm_parameter" "db_password" {
  name            = aws_ssm_parameter.db_password.name
  with_decryption = true
}

# Create a PostgreSQL RDS instance
resource "aws_db_instance" "default" {
  allocated_storage       = 20
  engine                 = "postgres"
  engine_version         = "16.3"
  instance_class         = "db.t4g.micro"
  db_name                = "postgres"

  username               = data.aws_ssm_parameter.db_username.value
  password               = data.aws_ssm_parameter.db_password.value

  db_subnet_group_name   = aws_db_subnet_group.default.name
  vpc_security_group_ids = [aws_security_group.default.id]
  skip_final_snapshot    = true
  publicly_accessible     = true

  identifier             = "ninhnh-vti-rds-instance"

  depends_on = [
    aws_ssm_parameter.db_username,
    aws_ssm_parameter.db_password
  ]

  tags = {
    Name = "ninhnh-vti-postgres-db-instance"
  }
}

# Create an Elastic Container Registry (ECR) to hold container images
resource "aws_ecr_repository" "my_ecr" {
  name = "backend"

  tags = {
    Name = "ninhnh-vti-ecr"
  }
}

# IAM Role for EKS Cluster
resource "aws_iam_role" "eks_cluster_role" {
  name = "ninhnh-vti-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "ninhnh-vti-eks-cluster-role"
  }
}

# Attach policies to the EKS Cluster IAM role
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_role.name
}

# Create an EKS Cluster
resource "aws_eks_cluster" "my_cluster" {
  name     = "ninhnh-vti-cluster"
  role_arn = aws_iam_role.eks_cluster_role.arn

  vpc_config {
    subnet_ids = aws_subnet.private_subnet[*].id  # Use private subnets for nodes
  }

  tags = {
    Name = "ninhnh-vti-cluster"
  }
}

# Create an Elastic IP for the NAT Gateway
resource "aws_eip" "nat_eip" {
  domain = "vpc"
}

# Create NAT Gateway for private subnet internet access
resource "aws_nat_gateway" "default" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id    = aws_subnet.public_subnet[0].id

  tags = {
    Name = "ninhnh-vti-nat-gateway"
  }
}

# IAM Role for EKS Node Group
resource "aws_iam_role" "eks_node_group_role" {
  name = "ninhnh-vti-eks-node-group-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "ninhnh-vti-eks-node-group-role"
  }
}

# Attach policies to the EKS Node Group IAM role
resource "aws_iam_role_policy_attachment" "eks_node_group_policy" {
  role       = aws_iam_role.eks_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  role       = aws_iam_role.eks_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "eks_registry_policy" {
  role       = aws_iam_role.eks_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# Create an EKS Node Group
resource "aws_eks_node_group" "my_node_group" {
  cluster_name    = aws_eks_cluster.my_cluster.name
  node_group_name = "ninhnh-vti-node-group"
  node_role_arn   = aws_iam_role.eks_node_group_role.arn

  subnet_ids = aws_subnet.private_subnet[*].id

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }

  depends_on = [aws_eks_cluster.my_cluster]
}

# IAM Role for EC2 (Jenkins)
resource "aws_iam_role" "jenkins_role" {
  name = "jenkins_role"

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

  tags = {
    Name = "ninhnh-vti-jenkins-role"
  }
}

# Attach policies to the Jenkins Role
resource "aws_iam_role_policy_attachment" "Jenkins_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
  role       = aws_iam_role.jenkins_role.name
}

# Security group for Jenkins
resource "aws_security_group" "jenkins_sg" {
  vpc_id = aws_vpc.default.id

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Allow HTTP access to Jenkins from anywhere
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Allow SSH access from anywhere
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ninhnh-vti-jenkins-sg"
  }
}

# Data source to get the latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true

  owners = ["137112412989"]  # Amazon's official AMI owner ID for Amazon Linux 2

  filter {
    name = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# Create Jenkins EC2 instance using the latest Amazon Linux 2 AMI
resource "aws_instance" "jenkins" {
  ami                    = data.aws_ami.amazon_linux.id  # Use the latest AMI
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public_subnet[0].id
  key_name               = "ninh_ssh_key"
  vpc_security_group_ids = [aws_security_group.jenkins_sg.id]
  associate_public_ip_address = true
  
  # Install Docker and Jenkins on startup
  user_data = <<-EOF
                #!/bin/bash
                yum update -y
                amazon-linux-extras install docker -y
                systemctl enable docker
                service docker start
                usermod -aG docker ec2-user
                # Pull the Jenkins image
                docker pull jenkins/jenkins:lts
                # Run Jenkins container with Docker socket mounted
                docker run -d --restart unless-stopped -p 8080:8080 -v /var/run/docker.sock:/var/run/docker.sock jenkins/jenkins:lts
                EOF

  tags = {
    Name = "ninhnh-vti-jenkins-instance"
  }
}

# Create a local file for environment variables
resource "local_file" "env_file" {
  content = <<-EOT
    EKS_CLUSTER_ENDPOINT=${aws_eks_cluster.my_cluster.endpoint}
    ECR_REPOSITORY_URL=${aws_ecr_repository.my_ecr.repository_url}
    RDS_ENDPOINT=${aws_db_instance.default.endpoint}
    JENKINS_URL=http://${aws_instance.jenkins.public_ip}:8080
    DB_INSTANCE_IDENTIFIER=${aws_db_instance.default.identifier}
    DB_USERNAME_SSM=${data.aws_ssm_parameter.db_username.value}
    DB_PASSWORD_SSM=${data.aws_ssm_parameter.db_password.value}
  EOT

  filename = "${path.module}/output.env"
}