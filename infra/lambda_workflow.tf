module "lambda_workflow" {
  source = "./modules/lambda_workflow"

  name_prefix            = var.project_name
  source_root            = local.lambda_source_root
  package_path           = local.lambda_package_path
  runtime                = var.lambda_runtime
  table_name             = module.findings_store.table_name
  table_arn              = module.findings_store.table_arn
  notification_topic_arn = module.notifications.topic_arn
  authorized_tcp_ports   = var.authorized_tcp_ports
  function_timeouts      = var.lambda_timeouts
}
