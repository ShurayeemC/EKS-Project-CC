output "vpc_id" {
  value = aws_vpc.EKS_Project_VPC.id
}

output "public_subnet_ids" {
  value = [aws_subnet.public-1.id, aws_subnet.public-2.id]
}

output "private_subnet_ids" {
  value = [aws_subnet.private-1.id, aws_subnet.private-2.id]
}

