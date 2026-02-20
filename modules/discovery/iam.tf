# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

# IAM Role for discovery processor Lambda
resource "aws_iam_role" "discovery_processor" {
  name = "${local.name_prefix}-discovery-processor-role-${random_string.suffix.result}"

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

# Basic Lambda execution policy
resource "aws_iam_role_policy_attachment" "discovery_processor_basic" {
  role       = aws_iam_role.discovery_processor.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# X-Ray tracing policy
resource "aws_iam_role_policy_attachment" "discovery_processor_tracing" {
  role       = aws_iam_role.discovery_processor.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

# Custom policy for discovery processor
resource "aws_iam_role_policy" "discovery_processor" {
  name = "${local.name_prefix}-discovery-processor-policy-${random_string.suffix.result}"
  role = aws_iam_role.discovery_processor.id

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
          "dynamodb:Scan"
        ]
        Resource = [
          aws_dynamodb_table.discovery_tracking.arn,
          var.tracking_table_arn,
          var.configuration_table_arn,
          "${var.tracking_table_arn}/index/*",
          "${var.configuration_table_arn}/index/*"
        ]
      },
      {
        Sid    = "AllowSQSAccess"
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:ChangeMessageVisibility",
          "sqs:SendMessage"
        ]
        Resource = [
          aws_sqs_queue.discovery_queue.arn,
          aws_sqs_queue.discovery_dlq.arn
        ]
      },
      {
        Sid    = "AllowS3Access"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          var.input_bucket_arn,
          var.working_bucket_arn,
          var.output_bucket_arn,
          "${var.input_bucket_arn}/*",
          "${var.working_bucket_arn}/*",
          "${var.output_bucket_arn}/*"
        ]
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

# KMS permissions if encryption key is provided
resource "aws_iam_role_policy" "discovery_processor_kms" {
  count = var.encryption_key_arn != null ? 1 : 0

  name = "${local.name_prefix}-discovery-processor-kms-policy-${random_string.suffix.result}"
  role = aws_iam_role.discovery_processor.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowKMSDecrypt"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = var.encryption_key_arn
      }
    ]
  })
}

# Allow Lambda to write logs
resource "aws_iam_role_policy" "discovery_processor_logs" {
  name = "${local.name_prefix}-discovery-processor-logs-policy-${random_string.suffix.result}"
  role = aws_iam_role.discovery_processor.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${local.name_prefix}-discovery-*"
      }
    ]
  })
}
