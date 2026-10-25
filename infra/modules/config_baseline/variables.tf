variable "name_prefix" {
  description = "Prefix used for Config resources."
  type        = string
}

variable "config_bucket_name" {
  description = "Optional explicit globally unique bucket name."
  type        = string
  default     = null
  nullable    = true
}

variable "record_all_resources" {
  description = "Record every supported AWS resource type."
  type        = bool
  default     = true
}

variable "enable_recorder" {
  description = "Set the recorder to enabled or stopped."
  type        = bool
  default     = true
}

variable "authorized_tcp_ports" {
  description = "Authorized ports used by the built-in open-security-group rule."
  type        = string
  default     = "80,443"
}

variable "config_rules" {
  description = "Map of managed Config rules to create."
  type = map(object({
    source_identifier = string
    input_parameters  = optional(map(string), {})
    message_type      = optional(string)
    frequency         = optional(string)
  }))
  default = {}

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
