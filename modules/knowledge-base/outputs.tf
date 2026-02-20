# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

output "knowledge_base_id" {
  description = "ID of the Bedrock Knowledge Base"
  value       = var.create_knowledge_base ? aws_bedrockagent_knowledge_base.this[0].id : null
}

output "knowledge_base_arn" {
  description = "ARN of the Bedrock Knowledge Base"
  value       = var.create_knowledge_base ? aws_bedrockagent_knowledge_base.this[0].arn : null
}

output "data_source_id" {
  description = "ID of the Bedrock Data Source"
  value       = var.create_knowledge_base ? aws_bedrockagent_data_source.this[0].id : null
}

output "vector_store_type" {
  description = "Type of vector store configured"
  value       = var.vector_store_type
}
