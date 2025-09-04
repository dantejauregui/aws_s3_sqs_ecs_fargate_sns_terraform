output "image_upload_bucket_name" {
  description = "Name of image_upload S3 bucket"
  value       = aws_s3_bucket.image_upload_bucket.bucket
}

output "image_upload_bucket_arn" {
  value = aws_s3_bucket.image_upload_bucket.arn
}