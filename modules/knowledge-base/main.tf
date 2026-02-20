# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

# Knowledge Base Module with S3 Vectors Support
# Implements features from v0.3.16 - S3 Vectors as alternative to OpenSearch

data "aws_partition" "current" {}
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  name_prefix = var.name

  # Vector store type: S3_VECTORS or OPENSEARCH
  vector_store_type = var.vector_store_type

  # Common tags
  common_tags = merge(var.tags, {
    Component = "KnowledgeBase"
  })
}

# Random string for unique resource names
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

##########################################################################
# Bedrock Knowledge Base
##########################################################################

resource "aws_bedrockagent_knowledge_base" "this" {
  count = var.create_knowledge_base ? 1 : 0

  name     = "${local.name_prefix}-kb-${random_string.suffix.result}"
  role_arn = aws_iam_role.knowledge_base[0].arn

  knowledge_base_configuration {
    type = "VECTOR"
    vector_knowledge_base_configuration {
      embedding_model_configuration {
        bedrock_embedding_model_configuration {
          dimensions = 1024
          # Using Titan embedding model
        }
      }
      embedding_model_arn = "arn:${data.aws_partition.current.partition}:bedrock:${data.aws_region.current.name}::foundation-model/${var.knowledge_base_model_id}"
    }
  }

  storage_configuration {
    type = local.vector_store_type == "S3_VECTORS" ? "S3" : "OPENSEARCH_SERVERLESS"

    dynamic "s3_configuration" {
      for_each = local.vector_store_type == "S3_VECTORS" ? [1] : []
      content {
        bucket_arn = var.s3_vectors_bucket_arn
      }
    }

    dynamic "opensearch_serverless_configuration" {
      for_each = local.vector_store_type == "OPENSEARCH" ? [1] : []
      content {
        collection_arn    = var.opensearch_collection_arn
        vector_index_name = "${local.name_prefix}-kb-index"
        field_mapping {
          metadata_field = "metadata"
          text_field     = "text"
          vector_field   = "vector"
        }
      }
    }
  }

  tags = local.common_tags
}

##########################################################################
# Bedrock Data Source
##########################################################################

resource "aws_bedrockagent_data_source" "this" {
  count = var.create_knowledge_base ? 1 : 0

  knowledge_base_id = aws_bedrockagent_knowledge_base.this[0].id
  name              = "${local.name_prefix}-kb-datasource-${random_string.suffix.result}"

  data_source_configuration {
    type = "S3"
    s3_configuration {
      bucket_arn = var.document_bucket_arn
    }
  }

  chunking_strategy {
    type = "FIXED_SIZE"
    fixed_size_chunking_configuration {
      max_tokens         = 300
      overlap_percentage = 20
    }
  }
}
