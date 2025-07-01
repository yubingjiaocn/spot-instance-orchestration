terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.0"

  backend "local" {}
}

provider "aws" {
  region = var.hub_region
}

module "hub" {
  source = "../modules/hub"
  providers = {
    aws = aws
  }
  region         = var.hub_region
  worker_regions = var.worker_regions
  prefix         = var.prefix
  instance_type  = var.instance_type
}
