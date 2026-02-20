# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

variable "name" {
  description = "Name prefix for knowledge base resources"
  type        = string
  default     = "knowledge-base"
}

variable "create_knowledge_base" {
  description = "Whether to create the Bedrock Knowledge Base"
  type        = bool
  default     = true
}

variable "vector_store_type" {
  description = "Vector store type: S3_VECTORS or OPENSEARCH"
  type        = string
  default     = "S3_VECTORS"

  validation {
    condition     = contains(["S3_VECTORS", "OPENSEARCH"], var.vector_store_type)
    error_message = "vector_store_type must be either S3_VECTORS or OPENSEARCH."
  }
}

variable "knowledge_base_model_id" {
  description = "Bedrock model ID for knowledge base embeddings"
  type        = string
  default     = "amazon.titan-embed-text-v2:0"
}

variable "s3_vectors_bucket_arn" {
  description = "ARN of S3 bucket for S3 Vectors storage (required if vector_store_type is S3_VECTORS)"
  type        = string
  default     = null
}

variable "document_bucket_arn" {
  description = "ARN of S3 bucket containing documents for the knowledge base"
  type        = string
}

variable "opensearch_collection_arn" {
  description = "ARN of OpenSearch collection (required if vector_store_type is OPENSEARCH)"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
