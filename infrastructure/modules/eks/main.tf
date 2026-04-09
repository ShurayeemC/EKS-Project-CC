resource "aws_eks_cluster" "SC-EKS-Cluster" {
  name = "SC-EKS-Cluster"

  access_config {
    authentication_mode = "API"
  }

  role_arn = var.cluster_role_arn

  vpc_config {
    subnet_ids = var.subnet_ids
    }
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

}

resource "aws_eks_addon" "vpc-cni" {
  cluster_name                = aws_eks_cluster.SC-EKS-Cluster.name
  addon_name                  = "vpc-cni"
  resolve_conflicts_on_update = "OVERWRITE" # Ensures AWS is source of truth and ignores manual changes
}

resource "aws_eks_addon" "coredns" {
  cluster_name                = aws_eks_cluster.SC-EKS-Cluster.name
  addon_name                  = "coredns"
  resolve_conflicts_on_update = "OVERWRITE"
}

resource "aws_eks_addon" "kube-proxy" {
  cluster_name                = aws_eks_cluster.SC-EKS-Cluster.name
  addon_name                  = "kube-proxy"
  resolve_conflicts_on_update = "OVERWRITE"

  # Used for internal k8 networking lives on the worker node. 
}
resource "aws_eks_addon" "eks-pod-identity-agent" {
  cluster_name                = aws_eks_cluster.SC-EKS-Cluster.name
  addon_name                  = "eks-pod-identity-agent"
  resolve_conflicts_on_update = "OVERWRITE"

}