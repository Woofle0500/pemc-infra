provider "aws" {
  region = "ap-south-1"
  default_tags {
    tags = {
      "pemc:environment" = var.environment
      "pemc:owner"       = var.owner
      "pemc:cost-center" = var.cost_center
      "pemc:managed-by"  = "terraform"
    }
  }
}