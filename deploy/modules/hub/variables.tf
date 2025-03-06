variable "prefix" {
  description = "Prefix to be added to all resource names"
  type        = string
}

variable "region" {
  description = "AWS region for the hub infrastructure"
  type        = string
}

variable "worker_regions" {
  description = "List of AWS regions where worker infrastructure will be deployed"
  type        = list(string)
}

variable "instance_type" {
  description = "EC2 instance type for spot instances"
  type        = string
  default     = "p5en.48xlarge"
}

variable "retry_wait_time" {
  description = "Wait time in seconds before retrying spot instance launch"
  type        = number
  default     = 600  # 10 minutes
}
