provider "aws" {
  region = "ap-south-1"
  default_tags {
    tags = {
      "pemc:environment" = "sandbox"
      "pemc:cost-center" = "sre"
      "pemc:managed-by"  = "terraform"
    }
  }
}
