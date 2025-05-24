terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# Random IDforuniqueness
resource "random_id" "suffix" {
  byte_length = 8
}

# S3 Bucket forfile uploads
resource "aws_s3_bucket" "file_uploads" {
  bucket        = "file-uploads-${random_id.suffix.hex}"
  force_destroy = true
}

# IAM Role forLambda
resource "aws_iam_role" "lambda_exec" {
  name = "lambda-exec-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Attach AWSLambdaBasicExecutionRole
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Custom policy forLambda to access S3
resource "aws_iam_policy" "s3_access" {
  name        = "lambda-s3-access-${random_id.suffix.hex}"
  description = "Policy for Lambda to access S3"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ],
        Effect   = "Allow",
        Resource = [
          aws_s3_bucket.file_uploads.arn,
          "${aws_s3_bucket.file_uploads.arn}/*"
        ]
      }
    ]
  })
}

# Attach custom S3 policy to Lambda role
resource "aws_iam_role_policy_attachment" "lambda_s3" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.s3_access.arn
}

# Lambda Function
resource "aws_lambda_function" "file_processor" {
  function_name    = "file-processor-${random_id.suffix.hex}"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.9"
  filename         = "../lambda_function.zip"
  source_code_hash = filebase64sha256("../lambda_function.zip")
  timeout          = 60

  environment {
    variables = {
      BUCKET_NAME = aws_s3_bucket.file_uploads.id
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic,
    aws_iam_role_policy_attachment.lambda_s3
  ]
}

# Permission forS3 to invoke Lambda
resource "aws_lambda_permission" "allow_bucket" {
  statement_id  = "AllowExecutionFromS3"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.file_processor.arn
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.file_uploads.arn
}

