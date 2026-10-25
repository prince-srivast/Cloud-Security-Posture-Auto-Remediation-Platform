module "approval_api" {
  source = "./modules/approval_api"

  name_prefix           = var.project_name
  stage_name            = var.api_stage_name
  approver_function_arn = module.lambda_workflow.approver_function_arn
  approver_invoke_arn   = module.lambda_workflow.approver_invoke_arn
  reporter_function_arn = module.lambda_workflow.reporter_function_arn
  reporter_invoke_arn   = module.lambda_workflow.reporter_invoke_arn
}
