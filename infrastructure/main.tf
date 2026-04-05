module "vpc" {
  source       = "./modules/vpc"
  cluster_name = "SC-EKS-Cluster"
}

module "iam" {
  source       = "./modules/iam"
  cluster_name = "SC-EKS-Cluster"
}

module "eks" {
  source           = "./modules/eks"
  cluster_name     = "SC-EKS-Cluster"
  cluster_role_arn = module.iam.eks_cluster_role
  node_role_arn    = module.iam.eks_node_groups
  subnet_ids       = module.vpc.private_subnet_ids
}


module "securitygroups" {
  source = "./modules/securitygroups"
  vpc_id = module.vpc.vpc_id

}

module "route53" {
  source      = "./modules/route53"
  domain_name = "sc-k8sapp.com"
}