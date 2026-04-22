resource "aws_eks_cluster" "SC-EKS-Cluster" {
  name = var.cluster_name

  access_config {
    authentication_mode = "API"
  }

  role_arn = var.cluster_role_arn

  vpc_config {
    subnet_ids = var.subnet_ids
  }

  tags = merge(var.common_tags, {
    Name = "SC-EKS-Cluster"
  })
}

resource "aws_eks_node_group" "example" {
  cluster_name    = aws_eks_cluster.SC-EKS-Cluster.name
  node_group_name = "SC-EKS-Node-Group"
  node_role_arn   = var.node_role_arn
  subnet_ids      = var.subnet_ids

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }

  update_config {
    max_unavailable = 1
  }

  tags = merge(var.common_tags, {
    Name = "SC-EKS-Node-Group"
  })
}

resource "aws_eks_addon" "vpc-cni" {
  cluster_name                = aws_eks_cluster.SC-EKS-Cluster.name
  addon_name                  = "vpc-cni"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = merge(var.common_tags, {
    Name = "vpc-cni"
  })
}

resource "aws_eks_addon" "coredns" {
  cluster_name                = aws_eks_cluster.SC-EKS-Cluster.name
  addon_name                  = "coredns"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = merge(var.common_tags, {
    Name = "coredns"
  })
}

resource "aws_eks_addon" "kube-proxy" {
  cluster_name                = aws_eks_cluster.SC-EKS-Cluster.name
  addon_name                  = "kube-proxy"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = merge(var.common_tags, {
    Name = "kube-proxy"
  })
}

resource "aws_eks_addon" "eks-pod-identity-agent" {
  cluster_name                = aws_eks_cluster.SC-EKS-Cluster.name
  addon_name                  = "eks-pod-identity-agent"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = merge(var.common_tags, {
    Name = "eks-pod-identity-agent"
  })
}