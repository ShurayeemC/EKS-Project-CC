variable "repository_name" {
  type        = string
  description = "Name of the ECR repository"
  default     = "sc-eks-ecr"
}

variable "aws_region" {
  type        = string
  description = "AWS region to deploy into"
  default     = "eu-west-2"
}

variable "common_tags" {
  type        = map(string)
  description = "Common tags applied to all resources"
  default = {
    Project     = "EKS-Platform"
    Environment = "production"
    Owner       = "platform-team"
    ManagedBy   = "terraform"
    Repository  = "github.com/ShurayeemC/EKS-Project-CC"
  }
}