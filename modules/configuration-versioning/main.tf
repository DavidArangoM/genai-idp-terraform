# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

# Configuration Versioning Module (v0.4.15)
# Manages multiple named configuration versions as complete snapshots

data "aws_partition" "current" {}
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  name_prefix = var.name

  # DynamoDB table name from ARN
  configuration_table_name = element(split("/", var.configuration_table_arn), 1)

  # Common tags
  common_tags = merge(var.tags, {
    Component = "ConfigurationVersioning"
  })
}

# Random string for unique resource names
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

##########################################################################
# Configuration Versions Lambda Function
##########################################################################

# Configuration Manager Lambda - handles CRUD operations for config versions
data "archive_file" "config_version_manager" {
  count = var.enable_configuration_versioning ? 1 : 0

  type        = "zip"
  source_dir  = "${path.module}/../../../sources/src/lambda/update_configuration"
  output_path = "${path.module}/config_version_manager.zip"

  excludes = [
    "*.so",
    "*.dist-info/**",
    "*.egg-info/**",
    "__pycache__/**",
    "*.pyc"
  ]
}

resource "aws_lambda_function" "config_version_manager" {
  count = var.enable_configuration_versioning ? 1 : 0

  function_name = "${local.name_prefix}-config-version-manager-${random_string.suffix.result}"
  role          = aws_iam_role.config_version_manager[0].arn
  handler       = "index.handler"
  runtime       = "python3.12"
  timeout       = 300
  memory_size   = 1024

  filename         = data.archive_file.config_version_manager[0].output_path
  source_code_hash = data.archive_file.config_version_manager[0].output_base64sha256

  layers = var.idp_common_layer_arns

  kms_key_arn = var.encryption_key_arn

  environment {
    variables = {
      CONFIGURATION_TABLE_NAME     = local.configuration_table_name
      ENABLE_VERSIONING            = "true"
      DEFAULT_VERSION              = var.default_config_version
      LAMBDA_COST_METERING_ENABLED = "true"
      LOG_LEVEL                    = var.log_level
      METRIC_NAMESPACE             = var.metric_namespace
    }
  }

  dynamic "vpc_config" {
    for_each = length(var.vpc_subnet_ids) > 0 ? [1] : []
    content {
      subnet_ids         = var.vpc_subnet_ids
      security_group_ids = var.vpc_security_group_ids
    }
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "config_version_manager" {
  count = var.enable_configuration_versioning ? 1 : 0

  name              = "/aws/lambda/${aws_lambda_function.config_version_manager[0].function_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.encryption_key_arn

  tags = local.common_tags
}

# Lambda permission for API Gateway
resource "aws_lambda_permission" "api_gateway_invoke_config" {
  count         = var.enable_configuration_versioning && var.api_id != null ? 1 : 0
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.config_version_manager[0].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${var.api_arn}/*"
}

##########################################################################
# Version Tracking DynamoDB Table Items
##########################################################################

# Store version metadata in DynamoDB
# Note: This is managed by the Lambda, but we can seed initial data if needed

##########################################################################
# IAM Roles and Policies
##########################################################################

resource "aws_iam_role" "config_version_manager" {
  count = var.enable_configuration_versioning ? 1 : 0
  name  = "${local.name_prefix}-config-version-manager-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "config_version_manager" {
  count = var.enable_configuration_versioning ? 1 : 0
  name  = "${local.name_prefix}-config-version-manager-policy"
  role  = aws_iam_role.config_version_manager[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowDynamoDBAccess"
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:BatchGetItem",
          "dynamodb:BatchWriteItem"
        ]
        Resource = [
          var.configuration_table_arn,
          "${var.configuration_table_arn}/index/*"
        ]
      },
      {
        Sid    = "AllowKMSAccess"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = var.encryption_key_arn
      },
      {
        Sid    = "AllowCloudWatchMetrics"
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "cloudwatch:namespace" = var.metric_namespace
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "config_version_manager_basic" {
  count      = var.enable_configuration_versioning ? 1 : 0
  role       = aws_iam_role.config_version_manager[0].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "config_version_manager_vpc" {
  count      = var.enable_configuration_versioning && length(var.vpc_subnet_ids) > 0 ? 1 : 0
  role       = aws_iam_role.config_version_manager[0].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy_attachment" "config_version_manager_xray" {
  count      = var.enable_configuration_versioning && var.lambda_tracing_mode != null ? 1 : 0
  role       = aws_iam_role.config_version_manager[0].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AWSXRayDaemonWriteAccess"
}
