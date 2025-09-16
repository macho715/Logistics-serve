terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.region
  
  default_tags {
    tags = {
      Project     = "HVDC-Logistics"
      Environment = var.environment
      ManagedBy   = "Terraform"
      Owner       = "Samsung-C&T"
    }
  }
}
