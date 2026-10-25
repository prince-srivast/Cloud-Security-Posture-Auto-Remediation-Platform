resource "aws_dynamodb_table" "findings" {
  name                        = var.table_name
  billing_mode                = "PAY_PER_REQUEST"
  hash_key                    = "finding_arn"
  range_key                   = "sort_key"
  deletion_protection_enabled = var.deletion_protection_enabled

  attribute {
    name = "finding_arn"
    type = "S"
  }
  attribute {
    name = "sort_key"
    type = "S"
  }
  point_in_time_recovery {
    enabled = var.point_in_time_recovery
  }
  server_side_encryption {
    enabled = true
  }
  lifecycle {
    prevent_destroy = true
  }
}
