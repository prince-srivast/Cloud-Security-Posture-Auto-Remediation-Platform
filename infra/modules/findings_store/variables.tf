variable "table_name" {
  description = "DynamoDB table name."
  type        = string
}

variable "point_in_time_recovery" {
  description = "Enable point-in-time recovery."
  type        = bool
  default     = true
}

variable "deletion_protection_enabled" {
  description = "Enable DynamoDB deletion protection."
  type        = bool
  default     = true
}
