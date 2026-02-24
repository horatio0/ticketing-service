terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# network
module "network" {
  source = "../../modules/network"
  env    = var.env
}

# compute
module "compute" {
  source             = "../../modules/compute"
  env                = var.env
  vpc_id             = module.network.vpc_id
  private_subnets_id = module.network.app_subnets_id
}

# database
module "database" {
  source         = "../../modules/database"
  env            = var.env
  vpc_id         = module.network.vpc_id
  db_subnets_id  = module.network.db_subnets_id
  eks_node_sg_id = module.compute.eks_node_sg_id
}

# cicd
module "cicd" {
  source       = "../../modules/cicd"
  env          = var.env
  github_owner = "horatio0"
  github_repo  = "ticketing-service"
}