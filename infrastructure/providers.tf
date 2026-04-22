terraform {
  required_version = ">= 1.5.0, < 2.0.0" # Pins Terraform version — prevents accidental upgrades to Terraform 2.x which may have breaking changes

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # Allows patch and minor updates within 5.x but not 6.x
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0" # Allows patch and minor updates within 2.x but not 3.x
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0" # Allows patch and minor updates within 2.x but not 3.x
    }
  }
}

provider "aws" {
  region = "eu-west-2"
}