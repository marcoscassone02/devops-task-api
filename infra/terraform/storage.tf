resource "aws_ebs_volume" "postgres_data" {
  availability_zone = aws_subnet.public.availability_zone
  type              = "gp3"
  size              = 10
  encrypted         = true

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-postgres-data"
  }
}

resource "aws_volume_attachment" "postgres_data" {
  device_name                    = "/dev/sdf"
  volume_id                      = aws_ebs_volume.postgres_data.id
  instance_id                    = aws_instance.api.id
  stop_instance_before_detaching = true
}