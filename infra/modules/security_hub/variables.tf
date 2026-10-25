variable "enable_security_hub" {
  description = "Enable Security Hub."
  type        = bool
  default     = true
}

variable "enable_foundational_standard" {
  description = "Enable AWS Foundational Security Best Practices."
  type        = bool
  default     = true
}

variable "standards_arn" {
  description = "Security Hub standards subscription ARN."
  type        = string
  default     = null
  nullable    = true
}
