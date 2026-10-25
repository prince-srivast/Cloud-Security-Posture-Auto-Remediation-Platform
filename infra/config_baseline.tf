module "config_baseline" {
  source = "./modules/config_baseline"

  name_prefix          = var.project_name
  config_bucket_name   = var.config_bucket_name
  record_all_resources = var.record_all_resources
  enable_recorder      = var.enable_config_recorder
  authorized_tcp_ports = var.authorized_tcp_ports
  config_rules         = var.config_rules
}
