# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

variable "name" {
  description = "Name prefix for discovery resources"
  type        = string
  default     = "discovery"
}

variable "working_bucket_arn" {
  description = "ARN of the S3 bucket used for temporary processing files"
  type        = string
}

variable "input_bucket_arn" {
  description = "ARN of the S3 bucket where source documents are stored"
  type        = string
}

variable "output_bucket_arn" {
  description = "ARN of the S3 bucket where processed results are stored"
  type        = string
}

variable "tracking_table_arn" {
  description = "ARN of the DynamoDB tracking table"
  type        = string
}

variable "configuration_table_arn" {
  description = "ARN of the DynamoDB configuration table"
  type        = string
}

variable "metric_namespace" {
  description = "CloudWatch metric namespace"
  type        = string
  default     = "IDP"
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

variable "idp_common_layer_arn" {
  description = "ARN of the IDP common Lambda layer"
  type        = string
}

variable "lambda_tracing_mode" {
  description = "X-Ray tracing mode for Lambda functions"
  type        = string
  default     = "Active"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
