variable "name_prefix" {
  description = "Prefix for Lambda function and IAM role names."
  type        = string
}

variable "source_root" {
  description = "Directory containing the Python application package."
  type        = string
}

variable "package_path" {
  description = "Zip archive destination."
  type        = string
}

variable "runtime" {
  description = "AWS Lambda runtime."
  type        = string
  default     = "python3.12"
}

variable "table_name" {
  description = "DynamoDB findings table name."
  type        = string
}

variable "table_arn" {
  description = "DynamoDB findings table ARN."
  type        = string
}

variable "notification_topic_arn" {
  description = "SNS topic ARN."
  type        = string
}

variable "authorized_tcp_ports" {
  description = "Comma-separated TCP ports protected by EC2.19 remediation."
  type        = string
  default     = "80,443"
}

variable "function_timeouts" {
  description = "Per-function Lambda timeout in seconds."
  type = object({
    processor  = number
    approver   = number
    remediator = number
    reporter   = number
  })
  default = {
    processor  = 30
    approver   = 60
    remediator = 60
    reporter   = 30
  }

  validation {
    condition = alltrue([
      for timeout in values(var.function_timeouts) : timeout >= 1 && timeout <= 900
    ])
    error_message = "Lambda timeouts must be from 1 to 900 seconds."
  }
}
