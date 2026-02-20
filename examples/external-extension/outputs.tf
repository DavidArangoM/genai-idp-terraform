# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Outputs for External Extension Example

output "audit_logs_table_name" {
  description = "Name of the audit logs DynamoDB table"
  value       = aws_dynamodb_table.audit_logs.name
}

output "audit_logs_table_arn" {
  description = "ARN of the audit logs DynamoDB table"
  value       = aws_dynamodb_table.audit_logs.arn
}

output "appsync_api_id" {
  description = "ID of the AppSync API being extended"
  value       = data.aws_appsync_graphql_api.idp.id
}

output "appsync_datasource_name" {
  description = "Name of the AppSync data source for audit logs"
  value       = aws_appsync_datasource.audit_logs.name
}

output "resolvers_created" {
  description = "List of resolvers created"
  value = [
    "Query.getDocumentAuditLogs",
    "Query.getUserAuditLogs",
    "Mutation.createAuditLog"
  ]
}

output "lambda_function_arn" {
  description = "ARN of the auto-logging Lambda function (if enabled)"
  value       = var.enable_auto_logging ? aws_lambda_function.audit_logger[0].arn : null
}

output "usage_example" {
  description = "Example GraphQL queries for the new resolvers"
  value       = <<EOF

# Query audit logs for a document
query GetDocumentAuditLogs {
  getDocumentAuditLogs(documentId: "doc-123", limit: 50) {
    documentId
    action
    userId
    timestamp
    details
  }
}

# Query audit logs by user
query GetUserAuditLogs {
  getUserAuditLogs(userId: "user-456", limit: 100) {
    documentId
    action
    timestamp
    details
  }
}

# Create audit log entry
mutation CreateAuditLog {
  createAuditLog(input: {
    documentId: "doc-123"
    action: "DOCUMENT_PROCESSING_STARTED"
    userId: "user-456"
    timestamp: "2024-01-20T10:30:00Z"
    details: { step: "OCR", confidence: 0.95 }
  }) {
    documentId
    action
    timestamp
  }
}
EOF
}
