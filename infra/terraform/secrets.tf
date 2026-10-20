ephemeral "random_password" "postgres" {
  length  = 32
  special = false
}

resource "aws_ssm_parameter" "postgres_password" {
  name        = "/${var.project_name}/${var.environment}/postgres/password"
  description = "Password used by the PostgreSQL database"
  type        = "SecureString"
  tier        = "Standard"

  value_wo         = ephemeral.random_password.postgres.result
  value_wo_version = 1

  lifecycle {
    prevent_destroy = true
  }
}