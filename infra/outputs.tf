output "api_url" {
  value = "https://${aws_api_gateway_rest_api.file_api.id}.execute-api.us-east-1.amazonaws.com/prod/"
}

output "file_bucket" {
  value = aws_s3_bucket.file_bucket.bucket
}

