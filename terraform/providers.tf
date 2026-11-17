terraform {
  required_version = ">= 1.10.0" # use_lockfile

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.80"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "kubeshop"
      Client      = "zibiska-korp"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}
