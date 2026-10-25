data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "random_id" "bucket_suffix" {
  count       = var.config_bucket_name == null ? 1 : 0
  byte_length = 4
}

resource "aws_s3_bucket" "config" {
  bucket = var.config_bucket_name != null ? var.config_bucket_name : "${var.name_prefix}-config-${data.aws_caller_identity.current.account_id}-${random_id.bucket_suffix[0].hex}"

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_public_access_block" "config" {
  bucket                  = aws_s3_bucket.config.id
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "config" {
  bucket = aws_s3_bucket.config.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_iam_role" "config" {
  name = "${var.name_prefix}-config-recorder"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "config.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "config" {
  role       = aws_iam_role.config.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}

resource "aws_iam_role_policy" "config_bucket" {
  name = "${var.name_prefix}-config-delivery"
  role = aws_iam_role.config.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetBucketAcl", "s3:ListBucket"]
        Resource = aws_s3_bucket.config.arn
      },
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject"]
        Resource = "${aws_s3_bucket.config.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/Config/*"
        Condition = {
          StringEquals = { "s3:x-amz-acl" = "bucket-owner-full-control" }
        }
      }
    ]
  })
}

resource "aws_s3_bucket_policy" "config" {
  bucket = aws_s3_bucket.config.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AWSConfigBucketPermissionsCheck"
        Effect    = "Allow"
        Principal = { Service = "config.amazonaws.com" }
        Action    = ["s3:GetBucketAcl", "s3:ListBucket"]
        Resource  = aws_s3_bucket.config.arn
        Condition = {
          StringEquals = { "AWS:SourceAccount" = data.aws_caller_identity.current.account_id }
        }
      },
      {
        Sid       = "AWSConfigBucketDelivery"
        Effect    = "Allow"
        Principal = { Service = "config.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.config.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/Config/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl"      = "bucket-owner-full-control"
            "AWS:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
}

resource "aws_config_configuration_recorder" "main" {
  name     = "${var.name_prefix}-recorder"
  role_arn = aws_iam_role.config.arn
  recording_group {
    all_supported                 = var.record_all_resources
    include_global_resource_types = false
  }
  depends_on = [aws_iam_role_policy_attachment.config, aws_iam_role_policy.config_bucket]
}

resource "aws_config_delivery_channel" "main" {
  name           = "${var.name_prefix}-delivery"
  s3_bucket_name = aws_s3_bucket.config.id
  depends_on = [
    aws_config_configuration_recorder.main,
    aws_s3_bucket_policy.config,
    aws_s3_bucket_server_side_encryption_configuration.config,
  ]
}

resource "aws_config_configuration_recorder_status" "main" {
  name       = aws_config_configuration_recorder.main.name
  is_enabled = var.enable_recorder
  depends_on = [aws_config_delivery_channel.main]
}

resource "aws_config_config_rule" "managed" {
  for_each = var.config_rules

  name = "${var.name_prefix}-${each.key}"
  source {
    owner             = "AWS"
    source_identifier = each.value.source_identifier

    dynamic "source_detail" {
      for_each = each.value.message_type == null ? [] : [each.value]
      content {
        message_type                = source_detail.value.message_type
        maximum_execution_frequency = source_detail.value.frequency
      }
    }
  }
  input_parameters = each.key == "authorized_ports" ? jsonencode(merge(
    each.value.input_parameters,
    { authorizedTcpPorts = var.authorized_tcp_ports }
  )) : length(each.value.input_parameters) > 0 ? jsonencode(each.value.input_parameters) : null
  depends_on = [aws_config_configuration_recorder_status.main]
}
