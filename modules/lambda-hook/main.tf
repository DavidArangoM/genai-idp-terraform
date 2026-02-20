# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

# Lambda Hook Inference Module (v0.4.15)
# Enables custom Lambda functions to be used as LLM inference backends

data "aws_partition" "current" {}
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  name = var.name

  # Common tags
  common_tags = merge(var.tags, {
    Component = "LambdaHook"
  })
}

# EventBridge Rule for Lambda Hook invocation events
resource "aws_cloudwatch_event_rule" "lambda_hook_invocation" {
  count       = var.enable_lambda_hook ? 1 : 0
  name        = "${local.name}-lambda-hook-invocation"
  description = "Route Lambda Hook inference requests"

  event_pattern = jsonencode({
    source      = ["idp.lambda-hook"]
    detail-type = ["LambdaHook Inference Request"]
  })

  tags = local.common_tags
}

# EventBridge Target for Lambda Hook
resource "aws_cloudwatch_event_target" "lambda_hook_target" {
  count    = var.enable_lambda_hook && var.lambda_hook_function_arn != null ? 1 : 0
  rule     = aws_cloudwatch_event_rule.lambda_hook_invocation[0].name
  arn      = var.lambda_hook_function_arn
  role_arn = aws_iam_role.eventbridge_lambda_hook[0].arn
}

# Lambda permission for EventBridge
resource "aws_lambda_permission" "eventbridge_invoke_hook" {
  count         = var.enable_lambda_hook && var.lambda_hook_function_arn != null ? 1 : 0
  statement_id  = "AllowEventBridgeInvokeHook"
  action        = "lambda:InvokeFunction"
  function_name = element(split(":", var.lambda_hook_function_arn), length(split(":", var.lambda_hook_function_arn)) - 1)
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.lambda_hook_invocation[0].arn
}

# IAM Role for EventBridge to invoke Lambda Hook
resource "aws_iam_role" "eventbridge_lambda_hook" {
  count = var.enable_lambda_hook && var.lambda_hook_function_arn != null ? 1 : 0
  name  = "${local.name}-eventbridge-lambda-hook-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "eventbridge_invoke_lambda" {
  count = var.enable_lambda_hook && var.lambda_hook_function_arn != null ? 1 : 0
  name  = "${local.name}-eventbridge-invoke-policy"
  role  = aws_iam_role.eventbridge_lambda_hook[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = var.lambda_hook_function_arn
      }
    ]
  })
}
