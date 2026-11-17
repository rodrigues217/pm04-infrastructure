terraform {
  # 1.10+ é necessário para o lock nativo do backend S3 (use_lockfile).
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.80"
    }
  }
}

provider "aws" {
  region = var.aws_region

  # Tags aplicadas a todos os recursos: facilitam o rateio de custos
  # e a identificação do que pertence a cada ambiente.
  default_tags {
    tags = {
      Project     = "kubeshop"
      Client      = "zibiska-korp"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}
