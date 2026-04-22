terraform {
  required_version = ">= 1.5.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "sc-terraform-statee"
    key            = "bootstrap/terraform.tfstate"
    region         = "eu-west-2"
    dynamodb_table = "sc-terraform-state-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
}