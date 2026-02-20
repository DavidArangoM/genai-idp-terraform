# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# External Extension Example for IDP Accelerator
# 
# This example demonstrates how to extend the IDP accelerator with custom
# AppSync resolvers and DynamoDB tables without modifying the core codebase.
#
# Use Case: Adding audit logging to track document processing events

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# -----------------------------------------------------------------------------
# 1. Get Reference to Existing IDP Resources
# -----------------------------------------------------------------------------

# Option A: If you know the exact API ID
# data "aws_appsync_graphql_api" "idp" {
#   api_id = "your-api-id-here"
# }

# Option B: Look up by name (if unique)
data "aws_appsync_graphql_api" "idp" {
  name = var.idp_appsync_api_name
}

# Get the IDP KMS key for encryption
# data "aws_kms_key" "idp" {
#   key_id = "alias/${var.idp_name_prefix}-key"
# }

# -----------------------------------------------------------------------------
# 2. Custom DynamoDB Table for Audit Logs
# -----------------------------------------------------------------------------

resource "aws_dynamodb_table" "audit_logs" {
  name         = "${var.name_prefix}-audit-logs"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "PK"
  range_key    = "SK"

  attribute {
    name = "PK"
    type = "S"
  }

  attribute {
    name = "SK"
    type = "S"
  }

  attribute {
    name = "GSI1PK"
    type = "S"
  }

  attribute {
    name = "GSI1SK"
    type = "S"
  }

  # Global Secondary Index for querying by user
  global_secondary_index {
    name            = "UserIndex"
    hash_key        = "GSI1PK"
    range_key       = "GSI1SK"
    projection_type = "ALL"
  }

  ttl {
    attribute_name = "ExpiresAfter"
    enabled        = true
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_key_arn
  }

  tags = merge(var.tags, {
    Component = "AuditLogging"
    Purpose   = "Document Processing Audit Trail"
  })
}

# -----------------------------------------------------------------------------
# 3. AppSync Data Source for Audit Table
# -----------------------------------------------------------------------------

resource "aws_appsync_datasource" "audit_logs" {
  api_id           = data.aws_appsync_graphql_api.idp.id
  name             = "AuditLogsDataSource"
  type             = "AMAZON_DYNAMODB"
  service_role_arn = aws_iam_role.appsync_audit_role.arn

  dynamodb_config {
    table_name = aws_dynamodb_table.audit_logs.name
    region     = data.aws_region.current.id
  }
}

# -----------------------------------------------------------------------------
# 4. AppSync Resolvers
# -----------------------------------------------------------------------------

# Query: Get audit logs for a specific document
resource "aws_appsync_resolver" "get_document_audit_logs" {
  api_id      = data.aws_appsync_graphql_api.idp.id
  type        = "Query"
  field       = "getDocumentAuditLogs"
  data_source = aws_appsync_datasource.audit_logs.name

  request_template = <<EOF
#set( $PK = "audit#doc#${ctx.args.documentId}" )
{
  "version": "2018-05-29",
  "operation": "Query",
  "query": {
    "expression": "PK = :pk",
    "expressionValues": {
      ":pk": $util.dynamodb.toDynamoDBJson($PK)
    }
  },
  "scanIndexForward": false,
  "limit": #if($ctx.args.limit) $ctx.args.limit #else 100 #end
}
EOF

  response_template = <<EOF
#if($ctx.error)
  $util.error($ctx.error.message, $ctx.error.type)
#end
$util.toJson($ctx.result.items)
EOF
}

# Query: Get audit logs by user
resource "aws_appsync_resolver" "get_user_audit_logs" {
  api_id      = data.aws_appsync_graphql_api.idp.id
  type        = "Query"
  field       = "getUserAuditLogs"
  data_source = aws_appsync_datasource.audit_logs.name

  request_template = <<EOF
#set( $GSI1PK = "user#${ctx.args.userId}" )
{
  "version": "2018-05-29",
  "operation": "Query",
  "index": "UserIndex",
  "query": {
    "expression": "GSI1PK = :gsipk",
    "expressionValues": {
      ":gsipk": $util.dynamodb.toDynamoDBJson($GSI1PK)
    }
  },
  "scanIndexForward": false,
  "limit": #if($ctx.args.limit) $ctx.args.limit #else 100 #end
}
EOF

  response_template = <<EOF
#if($ctx.error)
  $util.error($ctx.error.message, $ctx.error.type)
#end
$util.toJson($ctx.result.items)
EOF
}

# Mutation: Create audit log entry
resource "aws_appsync_resolver" "create_audit_log" {
  api_id      = data.aws_appsync_graphql_api.idp.id
  type        = "Mutation"
  field       = "createAuditLog"
  data_source = aws_appsync_datasource.audit_logs.name

  request_template = <<EOF
#set( $PK = "audit#doc#${ctx.args.input.documentId}" )
#set( $SK = "ts#${ctx.args.input.timestamp}#action#${ctx.args.input.action}" )
#set( $GSI1PK = "user#${ctx.args.input.userId}" )
#set( $GSI1SK = $SK )
{
  "version": "2018-05-29",
  "operation": "PutItem",
  "key": {
    "PK": $util.dynamodb.toDynamoDBJson($PK),
    "SK": $util.dynamodb.toDynamoDBJson($SK),
    "GSI1PK": $util.dynamodb.toDynamoDBJson($GSI1PK),
    "GSI1SK": $util.dynamodb.toDynamoDBJson($GSI1SK)
  },
  "attributeValues": $util.dynamodb.toMapValuesJson($ctx.args.input),
  "condition": {
    "expression": "attribute_not_exists(PK)"
  }
}
EOF

  response_template = <<EOF
#if($ctx.error)
  $util.error($ctx.error.message, $ctx.error.type)
#end
$util.toJson($ctx.result)
EOF
}

# -----------------------------------------------------------------------------
# 5. IAM Role for AppSync
# -----------------------------------------------------------------------------

resource "aws_iam_role" "appsync_audit_role" {
  name = "${var.name_prefix}-appsync-audit-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "appsync.amazonaws.com"
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "appsync_audit_policy" {
  name = "${var.name_prefix}-appsync-audit-policy"
  role = aws_iam_role.appsync_audit_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
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
        aws_dynamodb_table.audit_logs.arn,
        "${aws_dynamodb_table.audit_logs.arn}/index/*"
      ]
    }]
  })
}

# -----------------------------------------------------------------------------
# 6. Lambda Function to Auto-Log IDP Events (Optional)
# -----------------------------------------------------------------------------

resource "aws_lambda_function" "audit_logger" {
  count = var.enable_auto_logging ? 1 : 0

  function_name = "${var.name_prefix}-audit-logger"
  role          = aws_iam_role.audit_lambda_role[0].arn
  handler       = "index.handler"
  runtime       = "python3.12"
  timeout       = 30
  memory_size   = 256

  filename         = data.archive_file.audit_logger[0].output_path
  source_code_hash = data.archive_file.audit_logger[0].output_base64sha256

  environment {
    variables = {
      AUDIT_TABLE_NAME = aws_dynamodb_table.audit_logs.name
      LOG_LEVEL        = var.log_level
    }
  }

  tags = var.tags
}

resource "aws_iam_role" "audit_lambda_role" {
  count = var.enable_auto_logging ? 1 : 0
  name  = "${var.name_prefix}-audit-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "audit_lambda_policy" {
  count = var.enable_auto_logging ? 1 : 0
  name  = "${var.name_prefix}-audit-lambda-policy"
  role  = aws_iam_role.audit_lambda_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem"
        ]
        Resource = aws_dynamodb_table.audit_logs.arn
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

data "archive_file" "audit_logger" {
  count = var.enable_auto_logging ? 1 : 0

  type        = "zip"
  output_path = "${path.module}/audit_logger.zip"

  source {
    content  = <<EOF
import json
import boto3
import os
from datetime import datetime

def handler(event, context):
    """
    Lambda function to automatically log IDP events to audit table.
    Can be triggered by EventBridge rules for document processing events.
    """
    table_name = os.environ['AUDIT_TABLE_NAME']
    dynamodb = boto3.resource('dynamodb')
    table = dynamodb.Table(table_name)
    
    # Parse event
    document_id = event.get('documentId', 'unknown')
    action = event.get('action', 'unknown')
    user_id = event.get('userId', 'system')
    details = event.get('details', {})
    
    timestamp = datetime.utcnow().isoformat()
    
    # Create audit log entry
    item = {
        'PK': f"audit#doc#{document_id}",
        'SK': f"ts#{timestamp}#action#{action}",
        'GSI1PK': f"user#{user_id}",
        'GSI1SK': f"ts#{timestamp}#action#{action}",
        'documentId': document_id,
        'action': action,
        'userId': user_id,
        'timestamp': timestamp,
        'details': details,
        'source': 'lambda-auto-logger'
    }
    
    table.put_item(Item=item)
    
    return {
        'statusCode': 200,
        'body': json.dumps({'message': 'Audit log created', 'documentId': document_id})
    }
EOF
    filename = "index.py"
  }
}
