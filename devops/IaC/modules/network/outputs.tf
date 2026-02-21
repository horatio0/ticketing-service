output "vpc_id" {
  value       = aws_vpc.main.id
  description = "vpc id"
}

output "app_subnets_id" {
  value       = aws_subnet.private_app[*].id
  description = "private subnets (for app server) id"
}

output "public_subnets_id" {
  value       = aws_subnet.public[*].id
  description = "public subnets id"
}

output "db_subnets_id" {
  value       = aws_subnet.private_db[*].id
  description = "private subnets (for db) id"
}