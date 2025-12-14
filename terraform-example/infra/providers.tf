terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Update these to your state bucket/lock table before running terraform init
  backend "s3" {
    bucket         = "change-me-tf-state-bucket"
    key            = "fastapi-alb/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "change-me-tf-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
}
