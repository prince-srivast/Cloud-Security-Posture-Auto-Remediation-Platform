output "approval_endpoint" {
  description = "IAM-authenticated finding approval endpoint."
  value       = "${aws_api_gateway_stage.main.invoke_url}/approve"
}

output "compliance_report_endpoint" {
  description = "IAM-authenticated compliance report endpoint."
  value       = "${aws_api_gateway_stage.main.invoke_url}/report"
}

output "approval_client_policy_arn" {
  description = "IAM policy ARN granting access to the approval endpoint."
  value       = aws_iam_policy.approval_client.arn
}

output "report_client_policy_arn" {
  description = "IAM policy ARN granting read access to the report endpoint."
  value       = aws_iam_policy.report_client.arn
}
