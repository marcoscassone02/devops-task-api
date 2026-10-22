output "vpc_id" {
  description = "ID of the project VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_id" {
  description = "ID of the public subnet"
  value       = aws_subnet.public.id
}

output "api_security_group_id" {
  description = "ID of the API security group"
  value       = aws_security_group.api.id
}

output "api_instance_id" {
  description = "ID of the EC2 instance running the API"
  value       = aws_instance.api.id
}

output "api_public_ip" {
  description = "Public IPv4 address of the API instance"
  value       = aws_instance.api.public_ip
}

output "api_public_dns" {
  description = "Public DNS name of the API instance"
  value       = aws_instance.api.public_dns
}

output "github_actions_deploy_role_arn" {
  description = "IAM role assumed by GitHub Actions for deployments"
  value       = aws_iam_role.github_actions_deploy.arn
}

output "deployment_ssm_document_name" {
  description = "SSM document used to deploy the application"
  value       = aws_ssm_document.deploy_application.name
}

output "cloudwatch_log_group_name" {
  description = "CloudWatch log group containing container logs"
  value       = aws_cloudwatch_log_group.containers.name
}

output "cloudwatch_dashboard_name" {
  description = "CloudWatch dashboard for the application"
  value       = aws_cloudwatch_dashboard.application.dashboard_name
}

output "cloudwatch_alarm_names" {
  description = "CloudWatch alarms monitoring the application and EC2"
  value = [
    aws_cloudwatch_metric_alarm.application_errors.alarm_name,
    aws_cloudwatch_metric_alarm.ec2_high_cpu.alarm_name,
    aws_cloudwatch_metric_alarm.ec2_status_check.alarm_name,
  ]
}