output "EKS_CLUSTER_NAME" {
  value = module.compute.cluster_name
}

output "DB_ENDPOINT" {
  value = module.database.db_endpoint
}

output "DB_SM_ARN" {
  value = module.database.SM_ARN
}

output "ECR_URL" {
  value = module.cicd.ecr_repository_url
}

output "ECR_ROLE_ARN" {
  value = module.cicd.github_role_arn
}