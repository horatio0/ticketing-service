variable "vpc_cidr" {
  description = "Main VPC Cidr"
  type        = string
  default     = "10.0.0.0/16"
}

variable "env" {
  description = "Environment"
  type        = string
  default     = "prod"
}

variable "az" {
  description = "Availability Zones"
  type        = list(string)
  default     = ["ap-northeast-2a", "ap-northeast-2b"]
}

variable "public_subnets" {
  description = "public subnet cidr list"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnets" {
  description = "private subnet cidr list"
  type        = list(string)
  default     = ["10.0.3.0/24", "10.0.4.0/24"]
}