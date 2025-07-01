terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = "~> 5.0"
      configuration_aliases = [aws]
    }
  }
}




# Data sources
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}
