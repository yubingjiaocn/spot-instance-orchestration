# Common definitions for Step Functions to reduce duplication

# Common IAM policy statements for Step Functions
locals {
  # Common IAM policy statements
  common_iam_policies = {
    autoscaling = {
      actions = ["autoscaling:SetDesiredCapacity", "autoscaling:DescribeAutoScalingGroups"]
      resources = [module.autoscaling.autoscaling_group_arn]
    },
    lambda = {
      actions = ["lambda:InvokeFunction"]
      resources = ["*"]
    }
    ec2_describe = {
      actions = ["ec2:DescribeInstances"]
      resources = ["*"]
    }
    ecs_tasks = {
      actions = ["ecs:ListTasks", "ecs:StopTask", "ecs:RunTask", "ecs:DescribeTasks"]
      resources = [module.ecs.cluster_arn, "*"]
    }
    events = {
      actions = ["events:DescribeRule", "events:PutEvents", "events:PutRule", "events:PutTargets", "events:DeleteRule", "events:RemoveTargets"]
      resources = ["*"]
    }
    ssm = {
      actions = ["ssm:GetParameter"]
      resources = ["*"]
    }
    states = {
      actions = ["states:StartExecution"]
      resources = ["*"]
    }
    iam_pass = {
      actions = ["iam:PassRole"]
      resources = ["*"]
    }
    cloudwatch_logs = {
      actions = [
        "logs:CreateLogDelivery",
        "logs:GetLogDelivery",
        "logs:UpdateLogDelivery",
        "logs:DeleteLogDelivery",
        "logs:ListLogDeliveries",
        "logs:PutLogEvents",
        "logs:PutResourcePolicy",
        "logs:DescribeResourcePolicies",
        "logs:DescribeLogGroups"
      ]
      resources = ["*"]
    }
  }
}
