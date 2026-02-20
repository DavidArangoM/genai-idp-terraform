# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Variables for External Extension Example

variable "name_prefix" {
  description = "Name prefix for all resources created by this extension"
  type        = string
  default     = "idp-extension"
}

variable "idp_appsync_api_name" {
  description = "Name of the existing IDP AppSync GraphQL API to extend"
  type        = string
  
  validation {
    condition     = length(var.idp_appsync_api_name) > 0
    error_message = "The IDP AppSync API name must not be empty."
  }
}

variable "idp_name_prefix" {
  description = "Name prefix used by the IDP deployment (for looking up resources)"
  type        = string
  default     = "genai-idp"
}

variable "kms_key_arn" {
  description = "KMS key ARN for encrypting DynamoDB tables"
  type        = string
  default     = null
}

variable "enable_auto_logging" {
  description = "Enable automatic audit logging via Lambda function"
  type        = bool
  default     = false
}

variable "log_level" {
  description = "Log level for Lambda functions"
  type        = string
  default     = "INFO"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}

variable "custom_resolvers" {
  description = "List of custom resolvers to create"
  type = list(object({
    type        = string
    field       = string
    data_source = string
    template_dir = string
  }))
  default = []
}
