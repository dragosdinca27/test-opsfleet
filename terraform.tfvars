region          = "us-west-2"
name            = "eks-karpenter"
cluster_version = "1.30"
vpc_cidr        = "10.0.0.0/16"
private_subnets = ["10.0.32.0/19", "10.0.64.0/19", "10.0.96.0/19"]