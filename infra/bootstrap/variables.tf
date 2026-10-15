variable "aws_region" {
  description = "AWS region used for the Terraform state bucket"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used for resource identification"
  type        = string
  default     = "devops-task-api"
}