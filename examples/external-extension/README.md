# External Extension Example for IDP Accelerator

This example demonstrates **Option 1** for extending the IDP Accelerator: creating a separate, external Terraform module that adds custom AppSync resolvers and DynamoDB tables without modifying the core codebase.

## Overview

This extension adds **audit logging capabilities** to the IDP accelerator by:

1. Creating a new DynamoDB table for audit logs
2. Adding AppSync resolvers to query and create audit entries
3. (Optional) Auto-logging Lambda for IDP events

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Your Extension Module                     │
├─────────────────────────────────────────────────────────────┤
│  ┌──────────────────┐      ┌──────────────────────────────┐ │
│  │  Audit Logs      │      │   AppSync Resolvers          │ │
│  │  DynamoDB Table  │◄────►│   - getDocumentAuditLogs     │ │
│  │                  │      │   - getUserAuditLogs         │ │
│  │  PK: audit#doc   │      │   - createAuditLog           │ │
│  │  SK: ts#...      │      │                              │ │
│  │  GSI: UserIndex  │      └──────────────────────────────┘ │
│  └──────────────────┘                    │                   │
│                                          │                   │
│  ┌──────────────────┐      ┌─────────────▼──────────────┐   │
│  │  Auto-Logger     │      │  IDP AppSync API           │   │
│  │  Lambda (opt)    │─────►│  (Reference via data src)  │   │
│  └──────────────────┘      └────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## Prerequisites

1. **IDP Accelerator deployed** with AppSync API enabled
2. **Know your AppSync API name** (e.g., `genai-idp-api-*`)
3. **KMS key** for encryption (can use IDP's key or bring your own)

## Usage

### Step 1: Deploy IDP Accelerator First

Make sure the IDP accelerator is deployed with the API enabled:

```hcl
module "idp" {
  source = "./"
  
  # Enable AppSync API
  enable_api = true
  
  # Configure your processor
  bedrock_llm_processor = { ... }
  
  # ... other configuration
}
```

### Step 2: Deploy This Extension

```hcl
module "idp_audit_extension" {
  source = "./examples/external-extension"
  
  # Name prefix for this extension's resources
  name_prefix = "mycompany-audit"
  
  # Reference to the IDP AppSync API
  idp_appsync_api_name = "genai-idp-api-abc12345"
  
  # Optional: Enable auto-logging Lambda
  enable_auto_logging = true
  
  # Tags
  tags = {
    Environment = "production"
    Project     = "document-processing"
  }
}
```

### Step 3: Use the New Resolvers

After deployment, you can use these new GraphQL operations:

```graphql
# Query audit logs for a specific document
query {
  getDocumentAuditLogs(documentId: "doc-12345", limit: 50) {
    documentId
    action
    userId
    timestamp
    details
  }
}

# Query audit logs by user
query {
  getUserAuditLogs(userId: "user-789", limit: 100) {
    documentId
    action
    timestamp
    details
  }
}

# Create an audit log entry
mutation {
  createAuditLog(input: {
    documentId: "doc-12345"
    action: "EXTRACTION_COMPLETED"
    userId: "user-789"
    timestamp: "2024-01-20T10:30:00Z"
    details: { 
      step: "FIELD_EXTRACTION",
      confidence: 0.95,
      fieldsExtracted: 15
    }
  }) {
    documentId
    action
    timestamp
  }
}
```

## Resources Created

| Resource | Purpose | Cost |
|----------|---------|------|
| DynamoDB Table | Store audit logs | Pay per use |
| AppSync Data Source | Connect table to API | Free |
| AppSync Resolvers (3) | Query/Mutation handlers | Free |
| IAM Role | AppSync permissions | Free |
| Lambda Function (opt) | Auto-logging | Pay per use |

## Data Model

### Audit Log Entry Schema

```json
{
  "PK": "audit#doc#{documentId}",
  "SK": "ts#{timestamp}#action#{action}",
  "GSI1PK": "user#{userId}",
  "GSI1SK": "ts#{timestamp}#action#{action}",
  "documentId": "string",
  "action": "string (e.g., 'PROCESSING_STARTED', 'OCR_COMPLETED')",
  "userId": "string",
  "timestamp": "ISO8601",
  "details": "JSON object with event-specific data",
  "source": "string (who created the entry)"
}
```

### Access Patterns

1. **Get all audit logs for a document** → Query by PK
2. **Get audit logs for a user** → Query GSI by GSI1PK
3. **Get audit logs with time range** → Query by SK range

## Customization

### Adding More Resolvers

1. Edit `main.tf` and add new resolver resources:

```hcl
resource "aws_appsync_resolver" "my_custom_resolver" {
  api_id      = data.aws_appsync_graphql_api.idp.id
  type        = "Query"
  field       = "myCustomQuery"
  data_source = aws_appsync_datasource.audit_logs.name
  
  request_template = <<EOF
{
  "version": "2018-05-29",
  "operation": "Query",
  "query": {
    "expression": "PK = :pk AND begins_with(SK, :sk)",
    "expressionValues": {
      ":pk": $util.dynamodb.toDynamoDBJson($ctx.args.pk),
      ":sk": $util.dynamodb.toDynamoDBJson($ctx.args.prefix)
    }
  }
}
EOF

  response_template = "$util.toJson($ctx.result.items)"
}
```

2. Add to `outputs.tf`:
```hcl
output "my_resolver" {
  value = "Query.myCustomQuery"
}
```

### Adding More Tables

Copy the pattern from `aws_dynamodb_table.audit_logs`:

```hcl
resource "aws_dynamodb_table" "my_custom_table" {
  name         = "${var.name_prefix}-custom"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "PK"
  # ...
}

resource "aws_appsync_datasource" "my_custom" {
  api_id = data.aws_appsync_graphql_api.idp.id
  name   = "MyCustomDataSource"
  # ...
}
```

## Integration with IDP Events

To automatically log all IDP processing events:

1. Create EventBridge rules in your IDP deployment:

```hcl
# In your main IDP deployment
resource "aws_cloudwatch_event_rule" "document_processed" {
  name        = "idp-document-processed"
  description = "Capture document processing events"
  
  event_pattern = jsonencode({
    source      = ["idp.document"]
    detail-type = ["Document Processing Completed"]
  })
}

resource "aws_cloudwatch_event_target" "audit_logger" {
  rule     = aws_cloudwatch_event_rule.document_processed.name
  arn      = module.idp_audit_extension.lambda_function_arn
  role_arn = aws_iam_role.eventbridge.arn
}
```

2. The Lambda function will automatically create audit entries

## Cleanup

To remove this extension:

```bash
terraform destroy -target module.idp_audit_extension
```

**Note**: This will NOT affect the IDP accelerator - it's completely isolated.

## Troubleshooting

### Issue: "AppSync API not found"
- Check the `idp_appsync_api_name` variable
- Verify the API exists: `aws appsync list-graphql-apis`

### Issue: "Permission denied on DynamoDB"
- Check the IAM role has correct permissions
- Verify the table ARN is correct in the policy

### Issue: "Resolver returns empty results"
- Check the DynamoDB table has data
- Verify the query template syntax
- Enable CloudWatch Logs for AppSync

## Best Practices

1. **Use separate state file** for this extension
2. **Version your extension** independently from IDP
3. **Tag resources** clearly for cost tracking
4. **Enable TTL** on audit logs for cost savings
5. **Use GSI sparingly** (costs extra)
6. **Test resolvers** before production deployment

## Further Reading

- [AWS AppSync Resolver Mapping Templates](https://docs.aws.amazon.com/appsync/latest/devguide/resolver-mapping-template-reference.html)
- [DynamoDB Single-Table Design](https://aws.amazon.com/blogs/compute/creating-a-single-table-design-with-amazon-dynamodb/)
- [Terraform aws_appsync_resolver](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appsync_resolver)

---

## Summary

This example shows how to:
- ✅ Reference existing IDP resources
- ✅ Create custom DynamoDB tables
- ✅ Add AppSync resolvers
- ✅ Extend without modifying core IDP code
- ✅ Maintain separation of concerns

**This is Option 1: Clean, external, non-intrusive extension.**
