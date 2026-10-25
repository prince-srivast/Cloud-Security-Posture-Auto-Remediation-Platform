output "approver_function_arn" {
  description = "Approval Lambda function ARN."
  value       = aws_lambda_function.approver.arn
}

output "approver_invoke_arn" {
  description = "Approval Lambda invocation ARN for API Gateway."
  value       = aws_lambda_function.approver.invoke_arn
}

output "reporter_function_arn" {
  description = "Report Lambda function ARN."
  value       = aws_lambda_function.reporter.arn
}

output "reporter_invoke_arn" {
  description = "Report Lambda invocation ARN for API Gateway."
  value       = aws_lambda_function.reporter.invoke_arn
}
