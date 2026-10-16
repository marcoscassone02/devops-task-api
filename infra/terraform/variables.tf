variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name used to identify project resources"
  type        = string
  default     = "devops-task-api"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"
}

variable "allowed_api_cidr" {
  description = "IPv4 address allowed to access the API"
  type        = string

  validation {
    condition = (
      can(cidrhost(var.allowed_api_cidr, 0)) &&
      endswith(var.allowed_api_cidr, "/32")
    )
    error_message = "allowed_api_cidr must be a valid IPv4 CIDR ending in /32."
  }
}

variable "instance_type" {
  description = "EC2 instance type used to run the API and PostgreSQL"
  type        = string
  default     = "t3.small"

  validation {
    condition     = contains(["t3.micro", "t3.small", "t3.medium"], var.instance_type)
    error_message = "instance_type must be t3.micro, t3.small, or t3.medium."
  }
}