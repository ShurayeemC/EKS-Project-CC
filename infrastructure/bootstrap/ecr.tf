resource "aws_ecr_repository" "sc_eks_ecr" {
  name                 = var.repository_name
  image_tag_mutability = "IMMUTABLE"    # Prevents overwriting existing image tags — once pushed, a SHA tag can never be overwritten

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"             # KMS encryption instead of AES256 — gives you full control over the encryption key
  }

  tags = merge(var.common_tags, {
    Name = var.repository_name
  })
}