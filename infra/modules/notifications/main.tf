resource "aws_sns_topic" "notifications" {
  name              = var.topic_name
  kms_master_key_id = "alias/aws/sns"
}
