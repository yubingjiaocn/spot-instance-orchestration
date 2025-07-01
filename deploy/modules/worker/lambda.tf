# Lambda function for instance count calculation and IP address retrieval
module "instance_details_lambda" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "~> 7.20"

  function_name = "${var.prefix}-${var.region}-instance-details"
  description   = "Lambda function to calculate instance count and retrieve IP addresses"
  handler       = "app.lambda_handler"
  runtime       = "python3.13"
  memory_size   = 512
  timeout       = 30

  source_path = "${path.module}/../../../src/worker/get_instance_from_asg"

  environment_variables = {
    PREFIX     = var.prefix
    ASG_NAME   = module.autoscaling.autoscaling_group_name
    HUB_REGION = var.hub_region
  }

  create_role = true
  role_name   = "${var.prefix}-${var.region}-instance-details-role"

  attach_policy_statements = true
  policy_statements = {
    autoscaling = {
      effect    = "Allow",
      actions   = ["autoscaling:DescribeAutoScalingGroups"],
      resources = ["*"]
    },
    ec2_describe = {
      effect    = "Allow",
      actions   = ["ec2:DescribeInstances"],
      resources = ["*"]
    },
    events = {
      effect    = "Allow",
      actions   = ["events:PutEvents"],
      resources = ["*"]
    }
    ssm_params = {
      effect    = "Allow",
      actions   = ["ssm:PutParameter", "ssm:GetParameter"],
      resources = ["*"]
    }
  }

  publish = true

  tags = {
    Name = "${var.prefix}-${var.region}-instance-details"
  }
}
