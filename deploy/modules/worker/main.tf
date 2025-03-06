# EFS using terraform-aws-modules/efs/aws
module "efs" {
  source  = "terraform-aws-modules/efs/aws"
  version = "~> 1.0"

  name = "gpu-efs"

  # Select only one subnet per AZ to avoid mount target conflicts
  mount_targets = { for k, v in local.one_subnet_per_az : k => { subnet_id = v } }
  security_group_description = "EFS security group"
  security_group_vpc_id     = local.vpc_id
  security_group_rules = {
    ecs = {
      description              = "Allow ECS instances to access EFS"
      source_security_group_id = module.autoscaling_sg.security_group_id
    }
  }
  create_backup_policy = false
  enable_backup_policy = false
}

# VPC Data Source
locals {
  vpc_id = var.vpc_id != null ? var.vpc_id : data.aws_vpc.default.id
  subnet_ids = var.subnet_ids != null ? var.subnet_ids : data.aws_subnets.default.ids

  # Get one subnet per AZ to avoid EFS mount target conflicts
  subnet_to_az_map = { for id in local.subnet_ids : id => data.aws_subnet.selected[id].availability_zone }
  az_to_subnet_map = { for id, az in local.subnet_to_az_map : az => id... }
  one_subnet_per_az = { for az, subnets in local.az_to_subnet_map : az => subnets[0] }
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Get subnet details to determine AZs
data "aws_subnet" "selected" {
  for_each = toset(local.subnet_ids)
  id       = each.value
}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}
