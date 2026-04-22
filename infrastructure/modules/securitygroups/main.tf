resource "aws_security_group" "eks_node_sg" {
  name        = "eks_node_sg"
  description = "Allow TLS inbound traffic and all outbound traffic for EKS project"
  vpc_id      = var.vpc_id

  tags = merge(var.common_tags, {
    Name = "eks_node_sg"
  })
}

resource "aws_vpc_security_group_ingress_rule" "node_allow_443" {
  security_group_id = aws_security_group.eks_node_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
  description       = "Allow HTTPS inbound from internet to nodes"
}

resource "aws_vpc_security_group_ingress_rule" "node_allow_kubelet" {
  security_group_id            = aws_security_group.eks_node_sg.id
  referenced_security_group_id = aws_security_group.eks_control_plane_sg.id
  from_port                    = 10250
  ip_protocol                  = "tcp"
  to_port                      = 10250
  description                  = "Allow kubelet port from control plane security group only"
}

resource "aws_vpc_security_group_egress_rule" "node_allow_all_outbound" {
  security_group_id = aws_security_group.eks_node_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "Allow all outbound traffic from nodes"
}

resource "aws_security_group" "eks_control_plane_sg" {
  name        = "eks_control_plane_sg"
  description = "Security group for EKS control plane"
  vpc_id      = var.vpc_id

  tags = merge(var.common_tags, {
    Name = "eks_control_plane_sg"
  })
}

resource "aws_vpc_security_group_ingress_rule" "control_plane_allow_443" {
  security_group_id = aws_security_group.eks_control_plane_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
  description       = "Allow HTTPS inbound to control plane API server"
}

resource "aws_vpc_security_group_egress_rule" "control_plane_to_nodes" {
  security_group_id            = aws_security_group.eks_control_plane_sg.id
  referenced_security_group_id = aws_security_group.eks_node_sg.id
  from_port                    = 10250
  ip_protocol                  = "tcp"
  to_port                      = 10250
  description                  = "Allow control plane to reach kubelet on nodes only"
}

resource "aws_vpc_security_group_egress_rule" "control_plane_allow_outbound" {
  security_group_id = aws_security_group.eks_control_plane_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "Allow all outbound traffic from control plane"
}