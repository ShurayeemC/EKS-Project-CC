output "cluster_endpoint" {
  value = aws_eks_cluster.SC-EKS-Cluster.endpoint
}

output "cluster_ca_certificate" {
  value = aws_eks_cluster.SC-EKS-Cluster.certificate_authority[0].data
}

output "cluster_name" {
  value = aws_eks_cluster.SC-EKS-Cluster.name
}