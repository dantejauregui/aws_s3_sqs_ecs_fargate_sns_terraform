resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "image_upload_bucket" {
  bucket = "image-upload-bucket-${random_id.bucket_suffix.hex}"
}

#Creation of Folders inside S3 automatically:
resource "aws_s3_object" "prefix_uploads" {
  bucket  = aws_s3_bucket.image_upload_bucket.id
  key     = "uploads/"
  content = ""  # zero-byte object
}
resource "aws_s3_object" "prefix_thumbnails" {
  bucket  = aws_s3_bucket.image_upload_bucket.id
  key     = "thumbnails/"
  content = ""
}

resource "aws_s3_bucket_notification" "image_upload_bucket_eventbridge" {
  bucket      = aws_s3_bucket.image_upload_bucket.id
  eventbridge = true
}


# # OAC: lets CLOUDFRONT sign requests to S3:
# resource "aws_cloudfront_origin_access_control" "oac" {
#   name                              = "s3-oac"
#   origin_access_control_origin_type = "s3"
#   signing_behavior                  = "always"
#   signing_protocol                  = "sigv4"
# }

# # CloudFront distribution (origin points at your S3 bucket)
# #   - attach the OAC above to the origin
# #   - (not showing full distro for brevity)

# # Bucket policy: allow *only CloudFront* to read (optionally limit to thumbnails/)
# data "aws_caller_identity" "me" {}

# resource "aws_s3_bucket_policy" "allow_cloudfront" {
#   bucket = aws_s3_bucket.image_upload_bucket.id
#   policy = jsonencode({
#     Version = "2012-10-17",
#     Statement: [
#       {
#         Sid: "AllowCloudFrontRead",
#         Effect: "Allow",
#         Principal = { Service = "cloudfront.amazonaws.com" },
#         Action: ["s3:GetObject"],
#         Resource: "${aws_s3_bucket.image_upload_bucket.arn}/thumbnails/*",
#         Condition: {
#           StringEquals: {
#             "AWS:SourceArn": "arn:aws:cloudfront::${data.aws_caller_identity.me.account_id}:distribution/${aws_cloudfront_distribution.dist.id}"
#           }
#         }
#       }
#     ]
#   })
# }
