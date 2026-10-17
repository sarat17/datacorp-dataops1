output "bucket_staging" {
  value = aws_s3_bucket.staging_data.bucket
}

output "endpoint_prod" {
  value = aws_db_instance.prod.endpoint
}
