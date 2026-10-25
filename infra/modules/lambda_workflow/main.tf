data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "archive_file" "lambda_package" {
  type        = "zip"
  output_path = var.package_path

  dynamic "source" {
    for_each = fileset(var.source_root, "**/*.py")
    content {
      content  = file("${var.source_root}/${source.value}")
      filename = source.value
    }
  }
}

locals {
  functions = toset(["processor", "approver", "remediator", "reporter"])
}

resource "aws_iam_role" "lambda" {
  for_each = local.functions

  name = "${var.name_prefix}-${each.key}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  for_each = aws_iam_role.lambda

  role       = each.value.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "processor" {
  name = "${var.name_prefix}-processor"
  role = aws_iam_role.lambda["processor"].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem"]
        Resource = var.table_arn
      },
      {
        Effect   = "Allow"
        Action   = ["sns:Publish"]
        Resource = var.notification_topic_arn
      }
    ]
  })
}

resource "aws_iam_role_policy" "approver" {
  name = "${var.name_prefix}-approver"
  role = aws_iam_role.lambda["approver"].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem"]
        Resource = var.table_arn
      },
      {
        Effect   = "Allow"
        Action   = ["lambda:InvokeFunction"]
        Resource = aws_lambda_function.remediator.arn
      }
    ]
  })
}

resource "aws_iam_role_policy" "remediator" {
  name = "${var.name_prefix}-remediator"
  role = aws_iam_role.lambda["remediator"].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem"]
        Resource = var.table_arn
      },
      {
        Effect   = "Allow"
        Action   = ["s3:PutBucketPublicAccessBlock"]
        Resource = "*"
        Condition = {
          StringEquals = {
            "s3:ResourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      },
      {
        Effect   = "Allow"
        Action   = ["ec2:DescribeSecurityGroups"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["ec2:RevokeSecurityGroupIngress"]
        Resource = "arn:aws:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:security-group/*"
      },
      {
        Effect   = "Allow"
        Action   = ["sts:GetCallerIdentity"]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "reporter" {
  name = "${var.name_prefix}-reporter"
  role = aws_iam_role.lambda["reporter"].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["dynamodb:Scan"]
      Resource = var.table_arn
    }]
  })
}

resource "aws_lambda_function" "processor" {
  function_name    = "${var.name_prefix}-processor"
  role             = aws_iam_role.lambda["processor"].arn
  filename         = data.archive_file.lambda_package.output_path
  source_code_hash = data.archive_file.lambda_package.output_base64sha256
  runtime          = var.runtime
  handler          = "cloud_guard.processor.handler"
  timeout          = var.function_timeouts.processor

  environment {
    variables = {
      TABLE_NAME             = var.table_name
      NOTIFICATION_TOPIC_ARN = var.notification_topic_arn
    }
  }
  depends_on = [
    aws_iam_role_policy_attachment.lambda_logs["processor"],
    aws_iam_role_policy.processor,
  ]
}

resource "aws_lambda_function" "approver" {
  function_name    = "${var.name_prefix}-approver"
  role             = aws_iam_role.lambda["approver"].arn
  filename         = data.archive_file.lambda_package.output_path
  source_code_hash = data.archive_file.lambda_package.output_base64sha256
  runtime          = var.runtime
  handler          = "cloud_guard.approver.handler"
  timeout          = var.function_timeouts.approver

  environment {
    variables = {
      TABLE_NAME               = var.table_name
      REMEDIATOR_FUNCTION_NAME = "${var.name_prefix}-remediator"
    }
  }
  depends_on = [
    aws_iam_role_policy_attachment.lambda_logs["approver"],
    aws_iam_role_policy.approver,
  ]
}

resource "aws_lambda_function" "remediator" {
  function_name    = "${var.name_prefix}-remediator"
  role             = aws_iam_role.lambda["remediator"].arn
  filename         = data.archive_file.lambda_package.output_path
  source_code_hash = data.archive_file.lambda_package.output_base64sha256
  runtime          = var.runtime
  handler          = "cloud_guard.remediator.handler"
  timeout          = var.function_timeouts.remediator

  environment {
    variables = {
      TABLE_NAME           = var.table_name
      AUTHORIZED_TCP_PORTS = var.authorized_tcp_ports
    }
  }
  depends_on = [
    aws_iam_role_policy_attachment.lambda_logs["remediator"],
    aws_iam_role_policy.remediator,
  ]
}

resource "aws_lambda_function" "reporter" {
  function_name    = "${var.name_prefix}-reporter"
  role             = aws_iam_role.lambda["reporter"].arn
  filename         = data.archive_file.lambda_package.output_path
  source_code_hash = data.archive_file.lambda_package.output_base64sha256
  runtime          = var.runtime
  handler          = "cloud_guard.reporter.handler"
  timeout          = var.function_timeouts.reporter

  environment {
    variables = {
      TABLE_NAME = var.table_name
    }
  }
  depends_on = [
    aws_iam_role_policy_attachment.lambda_logs["reporter"],
    aws_iam_role_policy.reporter,
  ]
}

resource "aws_cloudwatch_event_rule" "securityhub" {
  name        = "${var.name_prefix}-securityhub-findings"
  description = "Route active Security Hub findings to the approval workflow."
  event_pattern = jsonencode({
    source        = ["aws.securityhub"]
    "detail-type" = ["Security Hub Findings - Imported"]
    detail = {
      findings = {
        RecordState = ["ACTIVE"]
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "processor" {
  rule      = aws_cloudwatch_event_rule.securityhub.name
  target_id = "finding-processor"
  arn       = aws_lambda_function.processor.arn
}

resource "aws_lambda_permission" "eventbridge_processor" {
  statement_id  = "AllowEventBridgeFindings"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.processor.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.securityhub.arn
}
