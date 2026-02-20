# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

output "config_version_manager_lambda_name" {
  description = "Name of the configuration version manager Lambda function"
  value       = var.enable_configuration_versioning ? aws_lambda_function.config_version_manager[0].function_name : null
}

output "config_version_manager_lambda_arn" {
  description = "ARN of the configuration version manager Lambda function"
  value       = var.enable_configuration_versioning ? aws_lambda_function.config_version_manager[0].arn : null
}

output "config_versioning_enabled" {
  description = "Whether configuration versioning is enabled"
  value       = var.enable_configuration_versioning
}

output "default_config_version" {
  description = "Default configuration version name"
  value       = var.default_config_version
}
