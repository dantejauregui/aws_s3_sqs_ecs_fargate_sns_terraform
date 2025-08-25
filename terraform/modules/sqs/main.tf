resource "aws_sqs_queue" "image_processing_queue" {
  name                        = "image-processing-queue"
  visibility_timeout_seconds  = 300
  message_retention_seconds   = 86400
  sqs_managed_sse_enabled     = true

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.image_processing_dlq.arn
    maxReceiveCount     = 4  # After 4 failed processing attempts, message goes to DLQ
  })
}

# Dead-letter queue:
resource "aws_sqs_queue" "image_processing_dlq" {
  name                        = "image-processing-dlq"
  message_retention_seconds   = 1209600  # 14 days max
  sqs_managed_sse_enabled     = true
}
