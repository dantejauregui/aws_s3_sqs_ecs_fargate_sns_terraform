variable "image_processing_queue_ARN" {}
variable "image_processing_queue_id" {}
variable "image_upload_bucket_name" {}

# Terraform registry url: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_rule
resource "aws_cloudwatch_event_rule" "s3_upload_event_rule" {
  name        = "capture-aws-sign-in"
  description = "Capture each AWS Console Sign In"

  event_pattern = jsonencode(
    {
        "source": ["aws.s3"],
        "detail-type": ["Object Created"],
        "detail": {
          "bucket": {
              "name": [var.image_upload_bucket_name]
          },
          # optional filter to only process "uploads/" keys:
          "object": {
            "key": [{
              "prefix": "uploads/"
            }]
          }
        }
    })
}
## The event-pattern json above was created in AWS Portal manually here: https://eu-central-1.console.aws.amazon.com/events/home?region=eu-central-1#/rules/create


# Terraform registry url: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_target
resource "aws_cloudwatch_event_target" "s3_event_to_sqs" {
  rule      = aws_cloudwatch_event_rule.s3_upload_event_rule.name
  target_id = "SendToSQS"
  arn       = var.image_processing_queue_ARN

  # The Input transformer feature of EventBridge  customizes the text/json from an event before it is passed to the target(SQS/ECS):
  input_transformer {
    input_paths = {
      bucket = "$.detail.bucket.name"
      key    = "$.detail.object.key"
    }

    input_template = <<EOF
{
  "bucket": <bucket>,
  "key": <key>
}
EOF
  }
}
# At the end, after the Input is transformed, the SQS/ECS target will receive a cleaner json for the Thumbnail task:
# {
#   "bucket": "image-upload-bucket",
#   "key": "uploads/your-photo.jpg"
# }




# Allow the specific EventBridge rule to SendMessage to your SQS queue:
resource "aws_sqs_queue_policy" "allow_eventbridge" {
  queue_url = var.image_processing_queue_id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement: [
      {
        Sid: "AllowEventBridgeToSend",
        Effect: "Allow",
        Principal: {
          Service: "events.amazonaws.com"
        },
        Action: "sqs:SendMessage",
        Resource: var.image_processing_queue_ARN,
        Condition: {
          ArnEquals: {
            "aws:SourceArn": aws_cloudwatch_event_rule.s3_upload_event_rule.arn
          }
        }
      }
    ]
  })
}
