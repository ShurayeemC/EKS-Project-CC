resource "aws_ecr_repository" "sc_eks_ecr" {
  name                 = var.repository_name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = merge(var.common_tags, {
    Name = var.repository_name
  })
}

output "ecr_repository_url" {
  value = aws_ecr_repository.sc_eks_ecr.repository_url
}