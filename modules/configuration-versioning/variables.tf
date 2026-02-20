# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

variable "name" {
  description = "Name prefix for configuration versioning resources"
  type        = string
  default     = "config-versioning"
}

variable "enable_configuration_versioning" {
  description = "Whether to enable Configuration Versioning (v0.4.15)"
  type        = bool
  default     = false
}

variable "configuration_table_arn" {
  description = "ARN of the DynamoDB configuration table"
  type        = string
}

variable "default_config_version" {
  description = "Default configuration version name"
  type        = string
  default     = "default"
}

variable "idp_common_layer_arns" {
  description = "List of Lambda layer ARNs (including idp_common)"
  type        = list(string)
  default     = []
}

variable "log_level" {
  description = "Log level for Lambda functions"
  type        = string
  default     = "INFO"
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}

variable "metric_namespace" {
  description = "CloudWatch metric namespace"
  type        = string
  default     = "IDP"
}

variable "encryption_key_arn" {
  description = "KMS key ARN for encryption"
  type        = string
  default     = null
}

variable "vpc_subnet_ids" {
  description = "List of VPC subnet IDs"
  type        = list(string)
  default     = []
}

variable "vpc_security_group_ids" {
  description = "List of VPC security group IDs"
  type        = list(string)
  default     = []
}

variable "lambda_tracing_mode" {
  description = "X-Ray tracing mode for Lambda"
  type        = string
  default     = null
}

variable "api_id" {
  description = "API Gateway ID for Lambda permissions"
  type        = string
  default     = null
}

variable "api_arn" {
  description = "API Gateway ARN for Lambda permissions"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
