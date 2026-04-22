locals {
  cluster_name = "SC-EKS-Cluster"
  common_tags = {
    Project     = "EKS-Platform"
    Environment = "production"
    Owner       = "platform-team"
    ManagedBy   = "terraform"
    Repository  = "github.com/ShurayeemC/EKS-Project-CC"
  }
}

module "vpc" {
  source       = "./modules/vpc"
  cluster_name = local.cluster_name
  common_tags  = local.common_tags
}

module "iam" {
  source       = "./modules/iam"
  cluster_name = local.cluster_name
  common_tags  = local.common_tags
}

module "eks" {
  source           = "./modules/eks"
  cluster_name     = local.cluster_name
  cluster_role_arn = module.iam.eks_cluster_role
  node_role_arn    = module.iam.eks_node_groups
  subnet_ids       = module.vpc.private_subnet_ids
  common_tags      = local.common_tags
}

module "securitygroups" {
  source      = "./modules/securitygroups"
  vpc_id      = module.vpc.vpc_id
  common_tags = local.common_tags
}

module "route53" {
  source      = "./modules/route53"
  domain_name = "sc-k8sapp.com"
  common_tags = local.common_tags
}