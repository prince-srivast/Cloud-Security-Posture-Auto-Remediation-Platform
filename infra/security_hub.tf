module "security_hub" {
  source = "./modules/security_hub"

  enable_security_hub          = var.enable_security_hub
  enable_foundational_standard = var.enable_foundational_standard
  standards_arn                = var.security_hub_standards_arn
}
