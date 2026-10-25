module "findings_store" {
  source = "./modules/findings_store"

  table_name                  = local.findings_table_name
  point_in_time_recovery      = var.findings_point_in_time_recovery
  deletion_protection_enabled = var.findings_deletion_protection_enabled
}
