resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "image_upload_bucket" {
  bucket = "image-upload-bucket-${random_id.bucket_suffix.hex}"
}

# resource "aws_s3_bucket_policy" "allow_access_from_another_account" {
#   bucket = aws_s3_bucket.example.id
#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Sid = "PublicRead"
#         Effect = "Allow"
#         Principal = {
#           AWS = "arn:aws:iam::${var.another_account_id}:root"
#         }
#         Action = "s3:GetObject"
#         Resource = "${aws_s3_bucket.input_images_bucket.arn}/*"
#       }
#     ]
#   })
# }