# Region configuration
variable "hub_region" {
  description = "The AWS region where the hub infrastructure will be deployed"
  type        = string
}

variable "worker_regions" {
  description = "List of AWS regions where worker infrastructure will be deployed"
  type        = list(string)
}

variable "prefix" {
  description = "Prefix to be added to all resource names"
  type        = string
}

variable "instance_type" {
  description = "Instance type for spot instance"
  type        = string
}