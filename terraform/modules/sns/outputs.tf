output "sns_topic_name" {
  description = "name of sns topic"
  value       = aws_sns_topic.user_updates.name
}
output "sns_topic_ARN" {
  description = "name of sns topic"
  value       = aws_sns_topic.user_updates.arn
}
