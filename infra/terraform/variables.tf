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