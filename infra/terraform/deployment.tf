resource "aws_iam_openid_connect_provider" "github_actions" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com",
  ]

  tags = {
    Name = "${var.project_name}-${var.environment}-github-actions"
  }
}

data "aws_iam_policy_document" "github_actions_assume_role" {
  statement {
    sid     = "GitHubActionsMainBranch"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type = "Federated"

      identifiers = [
        aws_iam_openid_connect_provider.github_actions.arn,
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"

      values = [
        "sts.amazonaws.com",
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"

      values = [
        "repo:marcoscassone02/devops-task-api:ref:refs/heads/main",
      ]
    }
  }
}

resource "aws_iam_role" "github_actions_deploy" {
  name = "${var.project_name}-${var.environment}-github-deploy"

  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role.json

  tags = {
    Name = "${var.project_name}-${var.environment}-github-deploy"
  }
}

resource "aws_ssm_document" "deploy_application" {
  name            = "${var.project_name}-${var.environment}-deploy"
  document_type   = "Command"
  document_format = "JSON"

  content = jsonencode({
    schemaVersion = "2.2"
    description   = "Deploy an exact DevOps Task API image to EC2"

    parameters = {
      imageTag = {
        type           = "String"
        description    = "Full Git commit SHA used as the GHCR image tag"
        allowedPattern = "^[0-9a-f]{40}$"
      }
    }

    mainSteps = [
      {
        action = "aws:runShellScript"
        name   = "deployApplication"

        inputs = {
          runCommand = [
            "set -euo pipefail",
            "git -C /opt/devops-task-api pull --ff-only origin main",
            "IMAGE_TAG=\"{{ imageTag }}\" docker compose -p devops-task-api -f /opt/devops-task-api/compose.yaml -f /opt/devops-task-api/compose.deploy.yaml config --quiet",
            "IMAGE_TAG=\"{{ imageTag }}\" docker compose -p devops-task-api -f /opt/devops-task-api/compose.yaml -f /opt/devops-task-api/compose.deploy.yaml pull api migrate",
            "IMAGE_TAG=\"{{ imageTag }}\" docker compose -p devops-task-api -f /opt/devops-task-api/compose.yaml -f /opt/devops-task-api/compose.deploy.yaml up -d --remove-orphans api",
            "curl --fail --silent --show-error --retry 12 --retry-delay 5 --retry-all-errors --connect-timeout 3 --max-time 10 http://localhost:8000/health",
          ]
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-${var.environment}-deploy"
  }
}

data "aws_iam_policy_document" "github_actions_deploy_permissions" {
  statement {
    sid     = "RunDeploymentDocument"
    effect  = "Allow"
    actions = ["ssm:SendCommand"]

    resources = [
      aws_ssm_document.deploy_application.arn,
      aws_instance.api.arn,
    ]
  }

  statement {
    sid    = "ReadDeploymentCommandResult"
    effect = "Allow"

    actions = [
      "ssm:GetCommandInvocation",
      "ssm:ListCommandInvocations",
    ]

    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "github_actions_deploy" {
  name = "${var.project_name}-${var.environment}-github-deploy"
  role = aws_iam_role.github_actions_deploy.name

  policy = data.aws_iam_policy_document.github_actions_deploy_permissions.json
}