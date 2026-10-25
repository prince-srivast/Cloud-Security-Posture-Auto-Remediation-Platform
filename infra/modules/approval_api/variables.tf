variable "name_prefix" {
  description = "Prefix for the API Gateway and IAM client policies."
  type        = string
}

variable "stage_name" {
  description = "API Gateway deployment stage."
  type        = string
  default     = "v1"
}

variable "approver_function_arn" {
  description = "Approval Lambda function ARN for invoke permission."
  type        = string
}

variable "approver_invoke_arn" {
  description = "Lambda invocation URI for the approval integration."
  type        = string
}

variable "reporter_function_arn" {
  description = "Report Lambda function ARN for invoke permission."
  type        = string
}

variable "reporter_invoke_arn" {
  description = "Lambda invocation URI for the report integration."
  type        = string
}
