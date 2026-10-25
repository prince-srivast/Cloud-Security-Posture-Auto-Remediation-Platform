variable "aws_region" {
  description = "AWS region for deployed resources."
  type        = string
}

variable "project_name" {
  description = "Lowercase prefix used in resource names."
  type        = string
  default     = "cloud-posture"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,20}$", var.project_name))
    error_message = "project_name must be 3–21 lowercase letters, digits, or hyphens, starting with a letter."
  }
}

variable "config_bucket_name" {
  description = "Optional name for the AWS Config delivery bucket."
  type        = string
  default     = null
  nullable    = true
}

variable "enable_config_recorder" {
  description = "Enable the AWS Config recorder."
  type        = bool
  default     = true
}

variable "record_all_resources" {
  description = "Record all supported resource types with AWS Config."
  type        = bool
  default     = true
}

variable "config_rules" {
  description = "Managed Config rules to create, keyed by resource-name suffix."
  type = map(object({
    source_identifier = string
    input_parameters  = optional(map(string), {})
    message_type      = optional(string)
    frequency         = optional(string)
  }))
  default = {
    s3_public_read = {
      source_identifier = "S3_BUCKET_PUBLIC_READ_PROHIBITED"
    }
    s3_public_write = {
      source_identifier = "S3_BUCKET_PUBLIC_WRITE_PROHIBITED"
    }
    ssh_restricted = {
      source_identifier = "INCOMING_SSH_DISABLED"
    }
    rdp_restricted = {
      source_identifier = "INCOMING_RDP_DISABLED"
    }
    authorized_ports = {
      source_identifier = "VPC_SG_OPEN_ONLY_TO_AUTHORIZED_PORTS"
      input_parameters = {
        authorizedTcpPorts = "80,443"
      }
      message_type = "ConfigurationItemChangeNotification"
      frequency    = "TwentyFour_Hours"
    }
  }

  validation {
    condition = alltrue([
      for rule in values(var.config_rules) :
      (rule.message_type == null && rule.frequency == null) ||
      (
        rule.message_type != null &&
        contains([
          "ConfigurationItemChangeNotification",
          "OversizedConfigurationItemChangeNotification",
          "ScheduledNotification",
          "ConfigurationSnapshotDeliveryCompleted",
          "Periodic",
        ], rule.message_type) &&
        rule.frequency != null &&
        contains(["One_Hour", "Three_Hours", "Six_Hours", "Twelve_Hours", "TwentyFour_Hours"], rule.frequency)
      )
    ])
    error_message = "Config source message_type and frequency must either both be omitted or be valid AWS Config source-detail values."
  }
}

variable "authorized_tcp_ports" {
  description = "Comma-separated TCP ports exempt from EC2.19 remediation."
  type        = string
  default     = "80,443"

  validation {
    condition = can(regex("^[0-9]+(,[0-9]+)*$", var.authorized_tcp_ports)) && alltrue([
      for port in split(",", var.authorized_tcp_ports) : try(
        tonumber(port) >= 1 && tonumber(port) <= 65535,
        false
      )
    ])
    error_message = "authorized_tcp_ports must be comma-separated TCP ports from 1 to 65535, with no spaces."
  }
}

variable "enable_security_hub" {
  description = "Enable Security Hub in this account and region."
  type        = bool
  default     = true
}

variable "enable_foundational_standard" {
  description = "Subscribe to AWS Foundational Security Best Practices."
  type        = bool
  default     = true
}

variable "security_hub_standards_arn" {
  description = "Optional Security Hub standards ARN override."
  type        = string
  default     = null
  nullable    = true
}

variable "findings_table_name" {
  description = "Optional DynamoDB table name."
  type        = string
  default     = null
  nullable    = true
}

variable "findings_point_in_time_recovery" {
  description = "Enable point-in-time recovery for findings and audit records."
  type        = bool
  default     = true
}

variable "findings_deletion_protection_enabled" {
  description = "Enable deletion protection on the findings table."
  type        = bool
  default     = true
}

variable "notification_topic_name" {
  description = "Optional SNS topic name."
  type        = string
  default     = null
  nullable    = true
}

variable "lambda_source_root" {
  description = "Python source directory, relative to this Terraform root."
  type        = string
  default     = "../src"
}

variable "lambda_package_path" {
  description = "Lambda zip output path, relative to this Terraform root."
  type        = string
  default     = ".terraform/cloud-posture-lambda.zip"
}

variable "lambda_runtime" {
  description = "Python runtime for the workflow Lambdas."
  type        = string
  default     = "python3.12"
}

variable "lambda_timeouts" {
  description = "Timeout in seconds for each Lambda function."
  type = object({
    processor  = optional(number, 30)
    approver   = optional(number, 60)
    remediator = optional(number, 60)
    reporter   = optional(number, 30)
  })
  default = {}
}

variable "api_stage_name" {
  description = "API Gateway stage name."
  type        = string
  default     = "v1"
}
