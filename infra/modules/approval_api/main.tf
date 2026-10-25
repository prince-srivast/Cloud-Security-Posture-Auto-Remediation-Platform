resource "aws_api_gateway_rest_api" "main" {
  name = "${var.name_prefix}-approval"
  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_resource" "approve" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "approve"
}

resource "aws_api_gateway_resource" "report" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "report"
}

resource "aws_api_gateway_method" "approve" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.approve.id
  http_method   = "POST"
  authorization = "AWS_IAM"
}

resource "aws_api_gateway_method" "report" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.report.id
  http_method   = "GET"
  authorization = "AWS_IAM"
}

resource "aws_api_gateway_integration" "approve" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.approve.id
  http_method             = aws_api_gateway_method.approve.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.approver_invoke_arn
}

resource "aws_api_gateway_integration" "report" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.report.id
  http_method             = aws_api_gateway_method.report.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.reporter_invoke_arn
}

resource "aws_lambda_permission" "approver" {
  statement_id  = "AllowApprovalApi"
  action        = "lambda:InvokeFunction"
  function_name = var.approver_function_arn
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/POST/approve"
}

resource "aws_lambda_permission" "reporter" {
  statement_id  = "AllowReportApi"
  action        = "lambda:InvokeFunction"
  function_name = var.reporter_function_arn
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/GET/report"
}

resource "aws_api_gateway_deployment" "main" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_method.approve.id,
      aws_api_gateway_integration.approve.id,
      aws_api_gateway_method.report.id,
      aws_api_gateway_integration.report.id,
    ]))
  }
  lifecycle {
    create_before_destroy = true
  }
  depends_on = [
    aws_api_gateway_integration.approve,
    aws_api_gateway_integration.report,
    aws_lambda_permission.approver,
    aws_lambda_permission.reporter,
  ]
}

resource "aws_api_gateway_stage" "main" {
  deployment_id = aws_api_gateway_deployment.main.id
  rest_api_id   = aws_api_gateway_rest_api.main.id
  stage_name    = var.stage_name
}

resource "aws_iam_policy" "approval_client" {
  name        = "${var.name_prefix}-approval-client"
  description = "Invoke the IAM-protected approval API."
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["execute-api:Invoke"]
      Resource = "${aws_api_gateway_rest_api.main.execution_arn}/*/POST/approve"
    }]
  })
}

resource "aws_iam_policy" "report_client" {
  name        = "${var.name_prefix}-report-client"
  description = "Read the IAM-protected compliance report API."
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["execute-api:Invoke"]
      Resource = "${aws_api_gateway_rest_api.main.execution_arn}/*/GET/report"
    }]
  })
}
