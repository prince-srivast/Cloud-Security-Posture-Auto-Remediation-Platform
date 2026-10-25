moved {
  from = random_id.config_bucket_suffix
  to   = module.config_baseline.random_id.bucket_suffix[0]
}

moved {
  from = aws_s3_bucket.config
  to   = module.config_baseline.aws_s3_bucket.config
}

moved {
  from = aws_s3_bucket_public_access_block.config
  to   = module.config_baseline.aws_s3_bucket_public_access_block.config
}

moved {
  from = aws_s3_bucket_server_side_encryption_configuration.config
  to   = module.config_baseline.aws_s3_bucket_server_side_encryption_configuration.config
}

moved {
  from = aws_iam_role.config
  to   = module.config_baseline.aws_iam_role.config
}

moved {
  from = aws_iam_role_policy_attachment.config
  to   = module.config_baseline.aws_iam_role_policy_attachment.config
}

moved {
  from = aws_iam_role_policy.config_bucket
  to   = module.config_baseline.aws_iam_role_policy.config_bucket
}

moved {
  from = aws_s3_bucket_policy.config
  to   = module.config_baseline.aws_s3_bucket_policy.config
}

moved {
  from = aws_config_configuration_recorder.main
  to   = module.config_baseline.aws_config_configuration_recorder.main
}

moved {
  from = aws_config_delivery_channel.main
  to   = module.config_baseline.aws_config_delivery_channel.main
}

moved {
  from = aws_config_configuration_recorder_status.main
  to   = module.config_baseline.aws_config_configuration_recorder_status.main
}

moved {
  from = aws_config_config_rule.s3_public_read
  to   = module.config_baseline.aws_config_config_rule.managed["s3_public_read"]
}

moved {
  from = aws_config_config_rule.s3_public_write
  to   = module.config_baseline.aws_config_config_rule.managed["s3_public_write"]
}

moved {
  from = aws_config_config_rule.ssh_restricted
  to   = module.config_baseline.aws_config_config_rule.managed["ssh_restricted"]
}

moved {
  from = aws_config_config_rule.rdp_restricted
  to   = module.config_baseline.aws_config_config_rule.managed["rdp_restricted"]
}

moved {
  from = aws_config_config_rule.authorized_ports
  to   = module.config_baseline.aws_config_config_rule.managed["authorized_ports"]
}

moved {
  from = aws_securityhub_account.main
  to   = module.security_hub.aws_securityhub_account.main[0]
}

moved {
  from = aws_securityhub_standards_subscription.foundational
  to   = module.security_hub.aws_securityhub_standards_subscription.foundational[0]
}

moved {
  from = aws_dynamodb_table.findings
  to   = module.findings_store.aws_dynamodb_table.findings
}

moved {
  from = aws_sns_topic.notifications
  to   = module.notifications.aws_sns_topic.notifications
}

moved {
  from = aws_iam_role.lambda["processor"]
  to   = module.lambda_workflow.aws_iam_role.lambda["processor"]
}

moved {
  from = aws_iam_role.lambda["approver"]
  to   = module.lambda_workflow.aws_iam_role.lambda["approver"]
}

moved {
  from = aws_iam_role.lambda["remediator"]
  to   = module.lambda_workflow.aws_iam_role.lambda["remediator"]
}

moved {
  from = aws_iam_role.lambda["reporter"]
  to   = module.lambda_workflow.aws_iam_role.lambda["reporter"]
}

moved {
  from = aws_iam_role_policy_attachment.lambda_logs["processor"]
  to   = module.lambda_workflow.aws_iam_role_policy_attachment.lambda_logs["processor"]
}

moved {
  from = aws_iam_role_policy_attachment.lambda_logs["approver"]
  to   = module.lambda_workflow.aws_iam_role_policy_attachment.lambda_logs["approver"]
}

moved {
  from = aws_iam_role_policy_attachment.lambda_logs["remediator"]
  to   = module.lambda_workflow.aws_iam_role_policy_attachment.lambda_logs["remediator"]
}

moved {
  from = aws_iam_role_policy_attachment.lambda_logs["reporter"]
  to   = module.lambda_workflow.aws_iam_role_policy_attachment.lambda_logs["reporter"]
}

moved {
  from = aws_iam_role_policy.processor
  to   = module.lambda_workflow.aws_iam_role_policy.processor
}

moved {
  from = aws_iam_role_policy.approver
  to   = module.lambda_workflow.aws_iam_role_policy.approver
}

moved {
  from = aws_iam_role_policy.remediator
  to   = module.lambda_workflow.aws_iam_role_policy.remediator
}

moved {
  from = aws_iam_role_policy.reporter
  to   = module.lambda_workflow.aws_iam_role_policy.reporter
}

moved {
  from = aws_lambda_function.processor
  to   = module.lambda_workflow.aws_lambda_function.processor
}

moved {
  from = aws_lambda_function.approver
  to   = module.lambda_workflow.aws_lambda_function.approver
}

moved {
  from = aws_lambda_function.remediator
  to   = module.lambda_workflow.aws_lambda_function.remediator
}

moved {
  from = aws_lambda_function.reporter
  to   = module.lambda_workflow.aws_lambda_function.reporter
}

moved {
  from = aws_cloudwatch_event_rule.securityhub
  to   = module.lambda_workflow.aws_cloudwatch_event_rule.securityhub
}

moved {
  from = aws_cloudwatch_event_target.processor
  to   = module.lambda_workflow.aws_cloudwatch_event_target.processor
}

moved {
  from = aws_lambda_permission.eventbridge_processor
  to   = module.lambda_workflow.aws_lambda_permission.eventbridge_processor
}

moved {
  from = aws_api_gateway_rest_api.approval
  to   = module.approval_api.aws_api_gateway_rest_api.main
}

moved {
  from = aws_api_gateway_resource.approve
  to   = module.approval_api.aws_api_gateway_resource.approve
}

moved {
  from = aws_api_gateway_resource.report
  to   = module.approval_api.aws_api_gateway_resource.report
}

moved {
  from = aws_api_gateway_method.approve
  to   = module.approval_api.aws_api_gateway_method.approve
}

moved {
  from = aws_api_gateway_method.report
  to   = module.approval_api.aws_api_gateway_method.report
}

moved {
  from = aws_api_gateway_integration.approve
  to   = module.approval_api.aws_api_gateway_integration.approve
}

moved {
  from = aws_api_gateway_integration.report
  to   = module.approval_api.aws_api_gateway_integration.report
}

moved {
  from = aws_lambda_permission.api_approver
  to   = module.approval_api.aws_lambda_permission.approver
}

moved {
  from = aws_lambda_permission.api_reporter
  to   = module.approval_api.aws_lambda_permission.reporter
}

moved {
  from = aws_api_gateway_deployment.approval
  to   = module.approval_api.aws_api_gateway_deployment.main
}

moved {
  from = aws_api_gateway_stage.approval
  to   = module.approval_api.aws_api_gateway_stage.main
}

moved {
  from = aws_iam_policy.approval_client
  to   = module.approval_api.aws_iam_policy.approval_client
}

moved {
  from = aws_iam_policy.report_client
  to   = module.approval_api.aws_iam_policy.report_client
}
