output "approval_endpoint" {
  description = "IAM-authenticated endpoint for approving or rejecting findings."
  value       = module.approval_api.approval_endpoint
}

output "compliance_report_endpoint" {
  description = "IAM-authenticated endpoint for the JSON compliance report."
  value       = module.approval_api.compliance_report_endpoint
}

output "approval_client_policy_arn" {
  description = "Policy ARN for roles allowed to approve remediations."
  value       = module.approval_api.approval_client_policy_arn
}

output "report_client_policy_arn" {
  description = "Policy ARN for roles allowed to read reports."
  value       = module.approval_api.report_client_policy_arn
}

output "notification_topic_arn" {
  description = "SNS topic ARN for finding notifications."
  value       = module.notifications.topic_arn
}

output "findings_table_name" {
  description = "DynamoDB table for workflow state and audit records."
  value       = module.findings_store.table_name
}

output "config_bucket_name" {
  description = "AWS Config delivery bucket name."
  value       = module.config_baseline.bucket_name
}
