# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

# Discovery Module
# Implements document discovery functionality from v0.3.15
# Automatically analyzes document samples to identify structure, field types, and organizational patterns

data "aws_partition" "current" {}
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  name_prefix = var.name

  # Extract bucket names from ARNs
  working_bucket_name  = element(split(":", var.working_bucket_arn), length(split(":", var.working_bucket_arn)) - 1)
  input_bucket_name    = element(split(":", var.input_bucket_arn), length(split(":", var.input_bucket_arn)) - 1)
  output_bucket_name   = element(split(":", var.output_bucket_arn), length(split(":", var.output_bucket_arn)) - 1)

  # Extract table names from ARNs
  tracking_table_name      = element(split("/", var.tracking_table_arn), 1)
  configuration_table_name = element(split("/", var.configuration_table_arn), 1)

  # Module build directory
  module_build_dir = "${path.module}/.terraform-build"

  # VPC config
  vpc_config = length(var.vpc_subnet_ids) > 0 ? {
    subnet_ids         = var.vpc_subnet_ids
    security_group_ids = var.vpc_security_group_ids
  } : null

  # Common tags
  common_tags = merge(var.tags, {
    Component = "Discovery"
  })
}

# Create module-specific build directory
resource "null_resource" "create_module_build_dir" {
  provisioner "local-exec" {
    command = "mkdir -p ${local.module_build_dir}"
  }
}

# Random string for unique resource names
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

##########################################################################
# Discovery Tracking DynamoDB Table
##########################################################################

resource "aws_dynamodb_table" "discovery_tracking" {
  name         = "${local.name_prefix}-discovery-tracking-${random_string.suffix.result}"
  billing_mode = "PAY_PER_REQUEST"

  hash_key = "jobId"

  attribute {
    name = "jobId"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  ttl {
    attribute_name = "ExpiresAfter"
    enabled        = true
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = var.encryption_key_arn
  }

  tags = local.common_tags
}

##########################################################################
# Discovery SQS Queue
##########################################################################

resource "aws_sqs_queue" "discovery_dlq" {
  name                       = "${local.name_prefix}-discovery-dlq-${random_string.suffix.result}"
  message_retention_seconds  = 1209600 # 14 days
  kms_master_key_id         = var.encryption_key_arn

  tags = local.common_tags
}

resource "aws_sqs_queue" "discovery_queue" {
  name                       = "${local.name_prefix}-discovery-queue-${random_string.suffix.result}"
  visibility_timeout_seconds = 930 # 15.5 minutes (Lambda timeout + buffer)
  message_retention_seconds  = 345600 # 4 days
  receive_wait_time_seconds  = 20
  kms_master_key_id         = var.encryption_key_arn

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.discovery_dlq.arn
    maxReceiveCount     = 3
  })

  tags = local.common_tags
}

##########################################################################
# Discovery Processor Lambda Function
##########################################################################

# Archive for discovery processor Lambda
data "archive_file" "discovery_processor" {
  type        = "zip"
  source_dir  = "${path.module}/../../../sources/src/lambda/discovery_processor"
  output_path = "${local.module_build_dir}/discovery-processor.zip_${random_string.suffix.result}"

  excludes = [
    "*.so",
    "*.dist-info/**",
    "*.egg-info/**",
    "__pycache__/**",
    "*.pyc",
    "boto3/**",
    "botocore/**"
  ]

  depends_on = [null_resource.create_module_build_dir]
}

resource "aws_lambda_function" "discovery_processor" {
  function_name = "${local.name_prefix}-discovery-processor-${random_string.suffix.result}"
  role          = aws_iam_role.discovery_processor.arn
  handler       = "index.handler"
  runtime       = "python3.12"
  timeout       = 900
  memory_size   = 3008

  filename         = data.archive_file.discovery_processor.output_path
  source_code_hash = data.archive_file.discovery_processor.output_base64sha256

  layers = [var.idp_common_layer_arn]

  kms_key_arn = var.encryption_key_arn

  environment {
    variables = {
      LOG_LEVEL                    = var.log_level
      METRIC_NAMESPACE             = var.metric_namespace
      TRACKING_TABLE               = local.tracking_table_name
      CONFIGURATION_TABLE_NAME     = local.configuration_table_name
      WORKING_BUCKET               = local.working_bucket_name
      DISCOVERY_QUEUE_URL          = aws_sqs_queue.discovery_queue.url
      LAMBDA_COST_METERING_ENABLED = "true"
      PROCESSING_CONTEXT           = "discovery"
    }
  }

  dynamic "vpc_config" {
    for_each = length(var.vpc_subnet_ids) > 0 ? [local.vpc_config] : []
    content {
      subnet_ids         = vpc_config.value.subnet_ids
      security_group_ids = vpc_config.value.security_group_ids
    }
  }

  tracing_config {
    mode = var.lambda_tracing_mode
  }

  tags = local.common_tags
}

# CloudWatch Log Group for discovery processor
resource "aws_cloudwatch_log_group" "discovery_processor" {
  name              = "/aws/lambda/${aws_lambda_function.discovery_processor.function_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.encryption_key_arn

  tags = local.common_tags
}

# Lambda event source mapping for SQS
resource "aws_lambda_event_source_mapping" "discovery_queue" {
  event_source_arn = aws_sqs_queue.discovery_queue.arn
  function_name    = aws_lambda_function.discovery_processor.arn
  batch_size       = 1
  enabled          = true
}
