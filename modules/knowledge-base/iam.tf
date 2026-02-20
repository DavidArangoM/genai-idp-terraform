# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

# IAM Role for Bedrock Knowledge Base
resource "aws_iam_role" "knowledge_base" {
  count = var.create_knowledge_base ? 1 : 0

  name = "${local.name_prefix}-kb-role-${random_string.suffix.result}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "bedrock.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

# Knowledge Base access policy
resource "aws_iam_role_policy" "knowledge_base" {
  count = var.create_knowledge_base ? 1 : 0

  name = "${local.name_prefix}-kb-policy-${random_string.suffix.result}"
  role = aws_iam_role.knowledge_base[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowBedrockInvokeModel"
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel"
        ]
        Resource = "arn:${data.aws_partition.current.partition}:bedrock:${data.aws_region.current.name}::foundation-model/${var.knowledge_base_model_id}"
      },
      {
        Sid    = "AllowS3Access"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          var.document_bucket_arn,
          "${var.document_bucket_arn}/*"
        ]
      },
      {
        Sid    = "AllowS3VectorsAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = local.vector_store_type == "S3_VECTORS" ? [
          var.s3_vectors_bucket_arn,
          "${var.s3_vectors_bucket_arn}/*"
        ] : []
      },
      {
        Sid    = "AllowOpenSearchAccess"
        Effect = "Allow"
        Action = [
          "aoss:APIAccessAll"
        ]
        Resource = local.vector_store_type == "OPENSEARCH" ? [var.opensearch_collection_arn] : []
      }
    ]
  })
}
