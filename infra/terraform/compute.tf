data "aws_ssm_parameter" "amazon_linux_2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_instance" "api" {
  ami                         = data.aws_ssm_parameter.amazon_linux_2023_ami.value
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.api.id]
  iam_instance_profile        = aws_iam_instance_profile.api.name
  associate_public_ip_address = true
  user_data = templatefile("${path.module}/scripts/user-data.sh.tftpl", {
    aws_region                       = var.aws_region
    postgres_ebs_volume_id           = aws_ebs_volume.postgres_data.id
    postgres_password_parameter_name = aws_ssm_parameter.postgres_password.name
    bootstrap_script                 = file("${path.module}/scripts/bootstrap.sh")
  })
  user_data_replace_on_change = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    encrypted             = true
    delete_on_termination = true
  }

  credit_specification {
    cpu_credits = "standard"
  }

  lifecycle {
    ignore_changes = [ami]
  }

  depends_on = [
    aws_iam_role_policy.postgres_password_read
  ]

  tags = {
    Name = "${var.project_name}-${var.environment}-api"
  }
}