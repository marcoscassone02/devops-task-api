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