module "notifications" {
  source = "./modules/notifications"

  topic_name = local.notification_topic_name
}
