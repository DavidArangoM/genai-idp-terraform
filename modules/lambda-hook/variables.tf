# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

variable "name" {
  description = "Name prefix for Lambda Hook resources"
  type        = string
  default     = "lambda-hook"
}

variable "enable_lambda_hook" {
  description = "Whether to enable Lambda Hook Inference (v0.4.15)"
  type        = bool
  default     = false
}

variable "lambda_hook_function_arn" {
  description = "ARN of the custom Lambda function for inference hook (optional, can be provided later)"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
