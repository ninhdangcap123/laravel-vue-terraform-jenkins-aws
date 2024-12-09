# Output the EKS cluster endpoint
output "eks_cluster_endpoint" {
  value = aws_eks_cluster.my_cluster.endpoint
}

# Output the ECR repository URL
output "ecr_repository_url" {
  value = aws_ecr_repository.my_ecr.repository_url
}

# Output the RDS instance endpoint
output "rds_endpoint" {
  value = aws_db_instance.default.endpoint
}

output "rds_instance_identifier" {
  value = aws_db_instance.default.id
}

# Output the Jenkins URL
output "jenkins_url" {
  value = "http://${aws_instance.jenkins.public_ip}:8080"
}

# Output SSM credentials for the database
output "db_username_ssm" {
  value = data.aws_ssm_parameter.db_username.value
  sensitive = true
}

output "db_password_ssm" {
  value = data.aws_ssm_parameter.db_password.value
  sensitive = true  # Masking sensitive data
}
