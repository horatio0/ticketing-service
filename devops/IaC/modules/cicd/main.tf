# ECR 생성
resource "aws_ecr_repository" "app_repo" {
  name                 = "${var.env}-java-app"
  image_tag_mutability = "MUTABLE" # 덮어쓰기 허용
  force_delete         = true      # terraform destroy시 내용물 있어도 강제 삭제 (실습용)

  image_scanning_configuration {
    scan_on_push = true # AWS가 제공하는 보안 스캔 기능
  }
}

# GitHub Action용 OIDC 등록
data "tls_certificate" "github_actions" {
  url = "https://token.actions.githubusercontent.com/.well-known/jwks"
}

resource "aws_iam_openid_connect_provider" "github_actions_oidc" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github_actions.certificates[0].sha1_fingerprint]
}

# GitHub Action용 IAM Role
resource "aws_iam_role" "github_actions" {
  name = "${var.env}-github-actions-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github_actions_oidc.arn
        }
        Condition = {
          StringLike = {
            # 정확히 '내 깃허브 레포지토리'에서만 이 권한을 쓸 수 있도록
            "token.actions.githubusercontent.com:sub" : "repo:${var.github_owner}/${var.github_repo}:*"
          }
          StringEquals = {
            "token.actions.githubusercontent.com:aud" : "sts.amazonaws.com"
          }
        }
      }
    ]
  })
}

# AWS 관리형 정책 사용 (ECR Power User)
resource "aws_iam_role_policy_attachment" "github_actions_ecr_power_user" {
  role       = aws_iam_role.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
}