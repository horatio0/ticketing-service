### 직접적인 서버 제작 ###

# EKS master node용 IAM Role
resource "aws_iam_role" "cluster" {
  name = "${var.cluster_name}-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
    }]
  })
}

# Master Node용 Policy
resource "aws_iam_role_policy_attachment" "cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}

# EKS 클러스터용 보안 그룹 (Master Node용)
resource "aws_security_group" "cluster_sg" {
  name        = "${var.cluster_name}-cluster-sg"
  description = "Security Group for EKS Cluster"

  vpc_id = var.vpc_id

  ingress {
    description = "Allow API Server to communicate with clients"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # 실무에선 회사 내부 ip를 넣어야 함
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.cluster_name}-cluster-sg"
  }
}

# EKS 마스터 클러스터 본체
resource "aws_eks_cluster" "main" {
  name       = var.cluster_name
  role_arn   = aws_iam_role.cluster.arn
  version    = var.k8s_version
  depends_on = [aws_iam_role_policy_attachment.cluster_policy]

  vpc_config {
    security_group_ids      = [aws_security_group.cluster_sg.id]
    subnet_ids              = var.private_subnets_id
    endpoint_public_access  = true # 로컬에서 마스터 API 접속 허용
    endpoint_private_access = true # 워커 노드에서 내부망으로 마스터 API 접속 허용
  }
}

# 워커 노드용 IAM Role
resource "aws_iam_role" "node" {
  name = "${var.cluster_name}-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

# 워커 노드용 AWS Policy 연결
resource "aws_iam_role_policy_attachment" "node_policy" {
  count      = length(var.node_policy_list)
  role       = aws_iam_role.node.name
  policy_arn = var.node_policy_list[count.index]
}

# EKS 워커 노드 그룹
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-node-group"
  node_role_arn   = aws_iam_role.node.arn

  subnet_ids     = var.private_subnets_id
  instance_types = var.instance_types
  ami_type       = "AL2023_x86_64_STANDARD"

  scaling_config {
    desired_size = var.desired_size # 기본 상태일때
    min_size     = var.min_size     # 최소
    max_size     = var.max_size     # 최대
  }

  depends_on = [
    aws_iam_role_policy_attachment.node_policy
  ]

  tags = {
    "Project"     = "ticketing"
    "Environment" = var.env
    "Role"        = "eks-node"
  }
}