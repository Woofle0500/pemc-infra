terraform {
  required_version = ">= 1.15.9, < 2.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.64"
    }
  }
}
