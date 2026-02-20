# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

output "discovery_queue_url" {
  description = "URL of the discovery SQS queue"
  value       = aws_sqs_queue.discovery_queue.url
}

output "discovery_queue_arn" {
  description = "ARN of the discovery SQS queue"
  value       = aws_sqs_queue.discovery_queue.arn
}

output "discovery_dlq_arn" {
  description = "ARN of the discovery dead letter queue"
  value       = aws_sqs_queue.discovery_dlq.arn
}

output "discovery_tracking_table_name" {
  description = "Name of the discovery tracking DynamoDB table"
  value       = aws_dynamodb_table.discovery_tracking.name
}

output "discovery_tracking_table_arn" {
  description = "ARN of the discovery tracking DynamoDB table"
  value       = aws_dynamodb_table.discovery_tracking.arn
}

output "discovery_processor_lambda_arn" {
  description = "ARN of the discovery processor Lambda function"
  value       = aws_lambda_function.discovery_processor.arn
}

output "discovery_processor_lambda_name" {
  description = "Name of the discovery processor Lambda function"
  value       = aws_lambda_function.discovery_processor.function_name
}
