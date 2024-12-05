output "ec2_public_ip" {
  description = "Public IP of the Laravel EC2 instance"
  value       = aws_instance.ninh_laravel_app.public_ip
}
