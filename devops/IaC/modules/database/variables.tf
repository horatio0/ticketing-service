variable "env" {
  type    = string
}

variable "db_subnets_id" {
  type        = list(string)
  description = "private subnets id from network module"
}

variable "vpc_id" {
  type        = string
  description = "vpc id from network module"
}

variable "db_name" {
  type    = string
  default = "my_rds"
}

variable "username" {
  type    = string
  default = "admin"
}

variable "eks_node_sg_id" {
  type        = string
  description = "default sg of cluster and worker node from compute module"
}