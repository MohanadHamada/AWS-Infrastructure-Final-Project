provider "aws" {
  region                   = var.region
}

# --- VPC Module ---
module "vpc" {
  source          = "./modules/vpc"
  project_name    = var.project_name
  vpc_cidr        = var.vpc_cidr
  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets
  azs             = var.azs
}

# --- EKS Module ---
module "eks" {
  source          = "./modules/eks"
  cluster_name    = "${var.project_name}-eks"
  cluster_version = var.eks_version
  vpc_id          = module.vpc.vpc_id
  private_subnets = module.vpc.private_subnets
  instance_type   = var.instance_type
  desired_size    = var.desired_size
  min_size        = var.min_size
  max_size        = var.max_size
  eks_admin_users = var.eks_admin_users
}

# --- ECR Module ---
module "ecr" {
  source   = "./modules/ecr"
  repo_name = "jenkins-nodejs-example"
}
