locals {
  cloudwatch_log_group_name   = "/${var.project_name}/${var.environment}/containers"
  cloudwatch_metric_namespace = "${var.project_name}/${var.environment}"
}

resource "aws_cloudwatch_log_group" "containers" {
  name              = local.cloudwatch_log_group_name
  retention_in_days = 7

  tags = {
    Name = "${var.project_name}-${var.environment}-containers"
  }
}

data "aws_iam_policy_document" "cloudwatch_logs_write" {
  statement {
    sid    = "WriteContainerLogs"
    effect = "Allow"

    actions = [
      "logs:CreateLogStream",
      "logs:DescribeLogStreams",
      "logs:PutLogEvents",
    ]

    resources = [
      "${aws_cloudwatch_log_group.containers.arn}:*",
    ]
  }
}

resource "aws_iam_role_policy" "cloudwatch_logs_write" {
  name   = "${var.project_name}-${var.environment}-cloudwatch-logs-write"
  role   = aws_iam_role.api.name
  policy = data.aws_iam_policy_document.cloudwatch_logs_write.json
}

resource "aws_cloudwatch_log_metric_filter" "application_errors" {
  name           = "${var.project_name}-${var.environment}-application-errors"
  pattern        = "?ERROR ?CRITICAL ?Traceback"
  log_group_name = aws_cloudwatch_log_group.containers.name

  metric_transformation {
    name          = "ApplicationErrors"
    namespace     = local.cloudwatch_metric_namespace
    value         = "1"
    default_value = "0"
    unit          = "Count"
  }
}

resource "aws_cloudwatch_metric_alarm" "application_errors" {
  alarm_name          = "${var.project_name}-${var.environment}-application-errors"
  alarm_description   = "Application containers emitted an error message"
  namespace           = local.cloudwatch_metric_namespace
  metric_name         = "ApplicationErrors"
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 3
  datapoints_to_alarm = 1
  threshold           = 1

  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
}

resource "aws_cloudwatch_metric_alarm" "ec2_high_cpu" {
  alarm_name          = "${var.project_name}-${var.environment}-ec2-high-cpu"
  alarm_description   = "EC2 CPU utilization was at least 80 percent for 3 of 5 minutes"
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 60
  evaluation_periods  = 5
  datapoints_to_alarm = 3
  threshold           = 80

  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    InstanceId = aws_instance.api.id
  }
}

resource "aws_cloudwatch_metric_alarm" "ec2_status_check" {
  alarm_name          = "${var.project_name}-${var.environment}-ec2-status-check"
  alarm_description   = "EC2 instance or system status checks are failing"
  namespace           = "AWS/EC2"
  metric_name         = "StatusCheckFailed"
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 3
  datapoints_to_alarm = 2
  threshold           = 1

  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "breaching"

  dimensions = {
    InstanceId = aws_instance.api.id
  }
}

resource "aws_cloudwatch_dashboard" "application" {
  dashboard_name = "${var.project_name}-${var.environment}"

  dashboard_body = jsonencode({
    start          = "-PT8H"
    periodOverride = "inherit"

    widgets = [
      {
        type   = "text"
        x      = 0
        y      = 0
        width  = 24
        height = 1

        properties = {
          markdown = "# DevOps Task API — ${var.environment}"
        }
      },
      {
        type   = "alarm"
        x      = 0
        y      = 1
        width  = 24
        height = 6

        properties = {
          title  = "Alarm status"
          region = var.aws_region
          alarms = [
            aws_cloudwatch_metric_alarm.application_errors.arn,
            aws_cloudwatch_metric_alarm.ec2_high_cpu.arn,
            aws_cloudwatch_metric_alarm.ec2_status_check.arn,
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 7
        width  = 12
        height = 6

        properties = {
          title  = "EC2 CPU utilization"
          region = var.aws_region
          view   = "timeSeries"
          period = 60
          stat   = "Average"

          metrics = [
            [
              "AWS/EC2",
              "CPUUtilization",
              "InstanceId",
              aws_instance.api.id,
            ],
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 7
        width  = 12
        height = 6

        properties = {
          title  = "EC2 network traffic"
          region = var.aws_region
          view   = "timeSeries"
          period = 60
          stat   = "Sum"

          metrics = [
            [
              "AWS/EC2",
              "NetworkIn",
              "InstanceId",
              aws_instance.api.id,
            ],
            [
              "AWS/EC2",
              "NetworkOut",
              "InstanceId",
              aws_instance.api.id,
            ],
          ]
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 13
        width  = 24
        height = 8

        properties = {
          title  = "Recent container logs"
          region = var.aws_region
          view   = "table"

          query = "SOURCE '${aws_cloudwatch_log_group.containers.name}' | fields @timestamp, @logStream, @message | sort @timestamp desc | limit 50"
        }
      },
    ]
  })
}