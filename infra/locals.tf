locals {
  findings_table_name     = coalesce(var.findings_table_name, "${var.project_name}-findings")
  notification_topic_name = coalesce(var.notification_topic_name, "${var.project_name}-approvals")
  lambda_source_root      = abspath("${path.root}/${var.lambda_source_root}")
  lambda_package_path     = abspath("${path.root}/${var.lambda_package_path}")
}
