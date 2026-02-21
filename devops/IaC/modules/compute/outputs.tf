output "cluster_name" {
  value = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.main.endpoint # 로컬이나 terraform에서 eks 마스터 노드에 api 쏠 때 필요함
}

output "cluster_auth" {
  value = aws_eks_cluster.main.certificate_authority[0].data # API 서버랑 통신할 때 필요한 인증 정보
}

output "eks_node_sg_id" {
  description = "default sg of cluster and worker node"
  value       = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}