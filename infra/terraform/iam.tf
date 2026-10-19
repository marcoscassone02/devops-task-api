data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "api" {
  name               = "${var.project_name}-${var.environment}-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.api.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "api" {
  name = "${var.project_name}-${var.environment}-ec2-profile"
  role = aws_iam_role.api.name
}

data "aws_iam_policy_document" "postgres_password_read" {
  statement {
    sid    = "ReadPostgresPassword"
    effect = "Allow"

    actions = [
      "ssm:GetParameter"
    ]

    resources = [
      aws_ssm_parameter.postgres_password.arn
    ]
  }
}

resource "aws_iam_role_policy" "postgres_password_read" {
  name   = "${var.project_name}-${var.environment}-postgres-password-read"
  role   = aws_iam_role.api.name
  policy = data.aws_iam_policy_document.postgres_password_read.json
}