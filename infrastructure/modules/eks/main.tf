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
