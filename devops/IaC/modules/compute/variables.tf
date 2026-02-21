variable "vpc_id" {
  type        = string
  description = "vpc id from network module"
}

variable "cluster_name" {
  type    = string
  default = "hello_k8s"
}

variable "k8s_version" {
  type    = string
  default = "1.34"
}

variable "node_policy_list" {
  type = list(string)
  default = [
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  ]
}

variable "private_subnets_id" { # prod/main.tf에서 넘겨주면 알아서 여기로 꽂아짐
  description = "private subnet list from network module"
  type        = list(string)
}

variable "instance_types" {
  description = "EC2 instance type"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "desired_size" {
  type    = number
  default = 3
}

variable "min_size" {
  type    = number
  default = 2
}

variable "max_size" {
  type    = number
  default = 5
}