terraform {
  required_version = "~> 1.15.9"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.64"
    }
  }
  backend "s3" {
    bucket       = "woofle-pemc-tfstate"
    key          = "live/sandbox/_bootstrap/terraform.tfstate"
    region       = "ap-south-1"
    encrypt      = true
    kms_key_id   = "arn:aws:kms:ap-south-1:730335219774:key/2a85860d-07ad-4881-9505-12eb93ca2ecf"
    use_lockfile = true
  }
}
