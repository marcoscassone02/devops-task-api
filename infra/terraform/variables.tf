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