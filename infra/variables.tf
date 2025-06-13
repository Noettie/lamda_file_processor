variable "region" {
  description = "AWS region"
  default     = "us-east-1"
}

variable "bucket_name" {
  description = "Existing S3 bucket name"
  default     = "lambda-file-processor-1073e95a"
}

variable "lambda_zip" {
  description = "Path to the Lambda deployment package"
  default     = "lambda.zip"
}

variable "notification_email" {
  description = "Email address for SNS notifications"
  default     = "thandonoe.ndlovu@gmail.com"
}

variable "ses_sender_email" {
  description = "Sender email address for SES"
  default     = "nottienoe.ndlovu@gmail.com"  # Replace with your verified SES sender email
}

variable "ses_recipient_email" {
  description = "Recipient email address for SES"
  default     = "nottienoe.ndlovu@gmail.com"  # Replace with your recipient email
}

variable "allowed_origin" {
  description = "CORS allowed origin for Lambda"
  default     = "*"
}

