# Launch Instance State Machine using terraform-aws-modules/step-functions/aws
module "launch_instance_step_function" {
  source  = "terraform-aws-modules/step-functions/aws"
  version = "~> 4.2"

  name     = "${var.prefix}-${var.region}-launch-spot-instance"

  # Create IAM role for Step Function
  create_role = true
  role_name   = "${var.prefix}-${var.region}-spot-instance-step-function-role"

  logging_configuration = {
    include_execution_data = true
    level                  = "ALL"
  }

  # IAM role policies
  attach_policy_statements = true
  policy_statements = [
    local.common_iam_policies.autoscaling,
    local.common_iam_policies.ec2_describe,
    local.common_iam_policies.ssm,
    local.common_iam_policies.ecs_tasks,
    local.common_iam_policies.events,
    local.common_iam_policies.states,
    local.common_iam_policies.iam_pass
  ]

  definition = jsonencode({
    StartAt = "ScaleUp"
    QueryLanguage = "JSONata"
    States = {
      ScaleUp = {
        Type = "Task"
        Resource = "arn:aws:states:::aws-sdk:autoscaling:setDesiredCapacity"
        Arguments = {
          AutoScalingGroupName = module.autoscaling.autoscaling_group_name
          DesiredCapacity = var.asg_desired_capacity
        }
        Assign = {
          "TaskToken": "{% $states.input.detail.TaskToken %}"
          "region": "{% $states.input.detail.region %}"
        }
        Next = "WaitForInstance"
      }
      WaitForInstance = {
        Type    = "Wait"
        Seconds = 90
        Next    = "StartCapacityMonitor"
      }
      StartCapacityMonitor = {
        Type = "Task"
        Resource = "arn:aws:states:::states:startExecution.sync"
        Arguments = {
          StateMachineArn = module.capacity_monitor_step_function.state_machine_arn
          Input = {
            "region": "{% $region %}"
            "notify": false
          }
        }
        Catch = [{
          ErrorEquals = ["States.ALL"]
          Next = "NotifyHubRegionFailed"
        }]
        Next = "LaunchTask"
      }
      LaunchTask = {
        Type = "Task"
        Resource = "arn:aws:states:::ecs:runTask"
        Arguments = {
          Cluster = module.ecs.cluster_arn
          TaskDefinition = aws_ecs_task_definition.main.arn
          LaunchType = "EC2"
        }
        Catch = [{
          ErrorEquals = ["States.ALL"]
          Next = "NotifyHubRegionFailed"
        }]
        Next = "NotifyHubRegionSuccess"
      }
      NotifyHubRegionSuccess = {
        Type     = "Task"
        Resource = "arn:aws:states:::events:putEvents"
        Arguments = {
          Entries = [{
            EventBusName = "default"
            Source       = "${var.prefix}.spotworker"
            DetailType   = "SpotCapacityFulfilled"
            Detail = {
              "operation": "launch_successful"
              "region": "{% $region %}"
              "TaskToken": "{% $TaskToken %}"
            }
          }]
        }
        End = true
      }
      NotifyHubRegionFailed = {
        Type     = "Task"
        Resource = "arn:aws:states:::events:putEvents"
        Arguments = {
          Entries = [{
            EventBusName = "default"
            Source       = "${var.prefix}.spotworker"
            DetailType   = "SpotCapacityNotFulfilled"
            Detail = {
              "operation": "launch_failure"
              "region": "{% $region %}"
              "TaskToken": "{% $TaskToken %}"
            }
          }]
        }
        Next = "ICEFailed"
      }
      ICEFailed = {
        Type = "Fail"
        Comment = "Spot instance capacity monitor failed"
      }
    }
  })

}

# EventBridge using terraform-aws-modules/eventbridge/aws
module "eventbridge" {
  source  = "terraform-aws-modules/eventbridge/aws"
  version = "~> 3.14"

  create_bus = false
  role_name  = "${var.prefix}-${var.region}-eventbridge-spot-instance-events-role"
  attach_sfn_policy = true
  sfn_target_arns   = [
    module.launch_instance_step_function.state_machine_arn,
    module.capacity_monitor_step_function.state_machine_arn,
    module.teardown_instance_step_function.state_machine_arn
  ]

  rules = {
    "${var.prefix}-${var.region}-spot-instance-request" = {
      name        = "${var.prefix}-${var.region}-spot-instance-request"
      description = "Handle spot instance requests from hub region"
      event_pattern = jsonencode({
        source      = ["${var.prefix}.spotorchestrator"]
        detail-type = ["SpotInstanceRequest"]
      })
    }
    "${var.prefix}-${var.region}-spot-interruption-warning" = {
      name        = "${var.prefix}-${var.region}-spot-interruption-warning"
      description = "Capture ASG events for spot instance terminating notice"
      event_pattern = jsonencode({
        source      = ["aws.ec2"]
        detail-type = [
          "EC2 Spot Instance Interruption Warning"
        ]
      })
    }
  }

  targets = {
    "${var.prefix}-${var.region}-spot-instance-request" = [
      {
        name            = "${var.prefix}-${var.region}-launch-spot-instance"
        arn             = module.launch_instance_step_function.state_machine_arn
        role_name       = "${var.prefix}-${var.region}-spot-instance-events-role"
        attach_role_arn = true
      }
    ]
    "${var.prefix}-${var.region}-spot-interruption-warning" = [
      {
        name            = "${var.prefix}-${var.region}-spot-interruption-warning"
        arn             = module.capacity_monitor_step_function.state_machine_arn
        role_name       = "${var.prefix}-${var.region}-spot-instance-events-role"
        attach_role_arn = true
      }
    ]
  }
}
