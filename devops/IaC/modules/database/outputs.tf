output "db_endpoint" {
  value = aws_db_instance.mysql.endpoint
}

output "SM_ARN" {
  description = "for Java app"
  value       = aws_secretsmanager_secret.db_credentials.arn
}