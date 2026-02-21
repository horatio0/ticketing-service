output "github_role_arn" {
  value = aws_iam_role.github_actions.arn
}

output "ecr_repository_url" {
  value = aws_ecr_repository.app_repo.repository_url
}