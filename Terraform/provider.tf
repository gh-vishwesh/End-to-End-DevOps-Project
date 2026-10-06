provider "aws" {
  region = "ap-south-1"
}

terraform {
  backend "s3" {
    bucket       = "terraform-devops-backendfile"
    region       = "ap-south-1"
    key          = "terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}
