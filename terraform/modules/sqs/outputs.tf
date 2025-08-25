output "image_processing_queue_ARN" {
  description = "ARN of sqs image_processing_queue"
  value       = aws_sqs_queue.image_processing_queue.arn
}

output "image_processing_queue_id" {
  description = "ID of sqs image_processing_queue"
  value       = aws_sqs_queue.image_processing_queue.id
}