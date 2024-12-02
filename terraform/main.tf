provider "aws" {
  region = "us-east-1"
}

resource "aws_instance" "laravel_app" {
  ami           = var.ami_id
  instance_type = "t4g.nano" # Smallest and cheapest instance
  key_name      = var.key_name

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y docker
              service docker start
              usermod -a -G docker ec2-user
              docker run -d -p 80:9000 your-docker-image:latest
              EOF

  tags = {
    Name = "Laravel-Vue-Server"
  }
}
