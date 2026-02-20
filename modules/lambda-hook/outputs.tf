# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

output "lambda_hook_eventbridge_rule_arn" {
  description = "ARN of the EventBridge rule for Lambda Hook invocations"
  value       = var.enable_lambda_hook ? aws_cloudwatch_event_rule.lambda_hook_invocation[0].arn : null
}

output "lambda_hook_eventbridge_rule_name" {
  description = "Name of the EventBridge rule for Lambda Hook invocations"
  value       = var.enable_lambda_hook ? aws_cloudwatch_event_rule.lambda_hook_invocation[0].name : null
}
