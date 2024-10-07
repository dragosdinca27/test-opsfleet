module "eks-karpenter" {
  source          = "./eks-karpenter"
  region          = var.region
  name            = var.name
  cluster_version = var.cluster_version
  vpc_cidr        = var.vpc_cidr
  private_subnets = var.private_subnets

  ## More variables could be configured
}