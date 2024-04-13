terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }

  backend "s3" {}
}

provider "aws" {
  default_tags {
    tags = {
      deployment_group = var.prefix
    }
  }
}
