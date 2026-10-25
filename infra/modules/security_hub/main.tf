data "aws_region" "current" {}

locals {
  standards_arn = var.standards_arn != null ? var.standards_arn : "arn:aws:securityhub:${data.aws_region.current.name}::standards/aws-foundational-security-best-practices/v/1.0.0"
}

resource "aws_securityhub_account" "main" {
  count = var.enable_security_hub ? 1 : 0
}

resource "aws_securityhub_standards_subscription" "foundational" {
  count         = var.enable_security_hub && var.enable_foundational_standard ? 1 : 0
  standards_arn = local.standards_arn
  depends_on    = [aws_securityhub_account.main]
}
